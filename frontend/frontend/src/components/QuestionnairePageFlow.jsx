import React, { useEffect, useState, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import ProgressBar from './ProgressBar';
import PageView from './PageView';
import {
  fetchPages,
  fetchPageAnswers,
  savePageAnswers,
  calculatePageProgress,
  cleanupUnreachablePages,
  resetAllForCluster,
  computeReachablePageIndices,
} from '../api';

// Flusso a pagine data-driven (analogo a QuestionnairePageFlowViewModel Swift)

export default function QuestionnairePageFlow() {
  const { cluster } = useParams();
  const navigate = useNavigate();
  const [pages, setPages] = useState([]);
  const [pageAnswers, setPageAnswers] = useState({}); // { pageId: { qid: value } }
  const [currentIndex, setCurrentIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [completed, setCompleted] = useState(false);
  const [progress, setProgress] = useState(0);
  const [resetting, setResetting] = useState(false);
  const [visitedStack, setVisitedStack] = useState([]); // array di indici pagina in ordine di visita

  // Carica pagine + risposte
  useEffect(() => {
    if (!cluster) return;
    let active = true;
    (async () => {
      setLoading(true); setError(null);
      try {
        const [pagesResp, answersResp] = await Promise.all([
          fetchPages(cluster),
          fetchPageAnswers(cluster)
        ]);
        if (!active) return;
        setPages(pagesResp.pages || []);
        setPageAnswers(answersResp.pageAnswers || {});
      } catch (e) {
        setError(e.message || 'Errore caricamento');
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => { active = false; };
  }, [cluster]);

  // Calcola indice della prima pagina incompleta
  const recomputeCurrentIndex = useCallback(() => {
    if (!pages.length) return 0;
    const flat = Object.values(pageAnswers || {}).reduce((acc, pa) => { Object.entries(pa || {}).forEach(([k,v]) => acc[k]=v); return acc; }, {});
    const reachable = computeReachablePageIndices(pages, flat);
    // Scorri solo le pagine raggiungibili in ordine di definizione
    for (let i = 0; i < pages.length; i++) {
      if (!reachable.has(i)) continue; // ignora non raggiungibili
      const page = pages[i];
      const req = (page.questions || []).filter(q => q.required);
      const saved = pageAnswers[page.id] || {};
      const done = req.every(q => saved[q.id] !== undefined && saved[q.id] !== null && saved[q.id] !== '');
      if (!done) return i;
    }
    // Se tutte le raggiungibili sono complete, tieni indice sull'ultima raggiungibile
    let lastReachable = 0;
    reachable.forEach(idx => { if (idx > lastReachable) lastReachable = idx; });
    return lastReachable;
  }, [pages, pageAnswers]);

  // Recalcola progresso
  useEffect(() => {
    const pct = calculatePageProgress(pages, pageAnswers);
    setProgress(pct);
    // Completamento solo sulle pagine raggiungibili
    const flat = Object.values(pageAnswers || {}).reduce((acc, pa) => { Object.entries(pa || {}).forEach(([k,v]) => acc[k]=v); return acc; }, {});
    const reachable = computeReachablePageIndices(pages, flat);
    let allReachableComplete = true;
    reachable.forEach(idx => {
      const page = pages[idx];
      const req = (page.questions || []).filter(q => q.required);
      const saved = pageAnswers[page.id] || {};
      const done = req.every(q => saved[q.id] !== undefined && saved[q.id] !== null && saved[q.id] !== '');
      if (!done) allReachableComplete = false;
    });
    setCompleted(allReachableComplete && pct === 100);
  }, [pages, pageAnswers]);

  // Aggiorna indice pagina attuale quando cambiano dati
  useEffect(() => {
    setCurrentIndex(recomputeCurrentIndex());
  }, [recomputeCurrentIndex]);

  // Mantieni lo stack coerente quando cambia currentIndex (push se nuovo)
  useEffect(() => {
    setVisitedStack(prev => {
      if (!pages.length) return [];
      if (currentIndex < 0 || currentIndex >= pages.length) return prev;
      if (prev.length === 0) return [currentIndex];
      const last = prev[prev.length - 1];
      if (last === currentIndex) return prev; // niente duplicati consecutivi
      // Se l'indice è già nello stack ma non è l'ultimo, lo tagliamo fino a quell'indice
      const existingPos = prev.indexOf(currentIndex);
      if (existingPos >= 0) return prev.slice(0, existingPos + 1);
      return [...prev, currentIndex];
    });
  }, [currentIndex, pages]);

  const handleSubmitPage = async (answers) => {
    const page = pages[currentIndex];
    if (!page) return;
    setSaving(true);
    try {
      // Salva localmente
      setPageAnswers(prev => ({ ...prev, [page.id]: answers }));
      await savePageAnswers(cluster, page.id, answers);
      window.dispatchEvent(new CustomEvent('progressChanged'));
      // Cleanup pagine non più raggiungibili dopo questo salvataggio
      try {
        const { updated, cleared } = await cleanupUnreachablePages(cluster, pages, { ...pageAnswers, [page.id]: answers });
        if (cleared.length) {
          setPageAnswers(updated);
          // Aggiorna progress immediatamente se necessario
        }
      } catch (e) {
        // non bloccare il flusso se cleanup fallisce
        // console.warn('Cleanup pagine non raggiungibili fallito', e);
      }

      // Nuova logica: dopo il salvataggio, determina l'indice della prossima pagina incompleta tra quelle raggiungibili.
      const flatAfter = Object.values({ ...pageAnswers, [page.id]: answers }).reduce((acc, pa) => { Object.entries(pa || {}).forEach(([k,v]) => acc[k]=v); return acc; }, {});
      const reachable = computeReachablePageIndices(pages, flatAfter);
      // Trova prima raggiungibile non completa
      let nextIdx = null;
      pages.forEach((p, idx) => {
        if (nextIdx !== null) return;
        if (!reachable.has(idx)) return;
        const req = (p.questions || []).filter(q => q.required);
        const saved = (idx === currentIndex) ? answers : (pageAnswers[p.id] || {});
        const done = req.every(q => saved[q.id] !== undefined && saved[q.id] !== null && saved[q.id] !== '');
        if (!done) nextIdx = idx;
      });
      if (nextIdx === null) {
        setCompleted(true);
      } else {
        setCurrentIndex(nextIdx);
      }
    } catch (e) {
      console.error('Errore salvataggio pagina', e);
      setError(e.message || 'Errore salvataggio');
    } finally {
      setSaving(false);
    }
  };

  const handleBack = () => {
    if (visitedStack.length <= 1) {
      navigate('/');
      return;
    }
    // Ritorna alla pagina precedente nello stack
    const newStack = visitedStack.slice(0, -1);
    const targetIndex = newStack[newStack.length - 1];
    const targetPage = pages[targetIndex];
    setVisitedStack(newStack);
    if (!targetPage) {
      setCurrentIndex(targetIndex);
      return;
    }
    // Cancella risposte della pagina di destinazione prima di atterrare
    setPageAnswers(prev => {
      const updated = { ...prev, [targetPage.id]: {} };
      (async () => {
        try {
          await savePageAnswers(cluster, targetPage.id, {});
          try {
            const { updated: cleaned } = await cleanupUnreachablePages(cluster, pages, updated);
            if (cleaned) setPageAnswers(cleaned);
          } catch {}
          window.dispatchEvent(new CustomEvent('progressChanged'));
        } catch (e) {
          console.error('Errore reset pagina on back', e);
        }
      })();
      return updated;
    });
    setCurrentIndex(targetIndex);
  };

  const handleRestart = async () => {
    if (!cluster) return;
    setResetting(true);
    try {
      await resetAllForCluster(cluster);
      setPageAnswers({});
      setCompleted(false);
      setCurrentIndex(0);
      window.dispatchEvent(new CustomEvent('progressChanged'));
    } finally {
      setResetting(false);
    }
  };

  if (loading) return <div>Caricamento...</div>;
  if (error) return <div>Errore: {error} <button onClick={() => navigate('/')}>Indietro</button></div>;
  if (!pages.length) return <div>Nessuna pagina disponibile <button onClick={() => navigate('/')}>Indietro</button></div>;

  if (completed) {
    return (
      <div className="completed-wrap">
        <ProgressBar value={100} />
        <h2>Questionario completato</h2>
        <div className="nav-row">
          <button className="btn-back" onClick={() => navigate('/')}>Torna all'elenco</button>
          <button className="btn-back" disabled={resetting} onClick={handleRestart}>{resetting ? 'Reset...' : 'Ricomincia'}</button>
        </div>
      </div>
    );
  }

  const page = pages[currentIndex];
  const initialAnswers = pageAnswers[page.id] || {};

  return (
    <div className="page-flow">
      <ProgressBar value={progress} />
      <PageView
        page={page}
        initialAnswers={initialAnswers}
        onSubmit={handleSubmitPage}
        loadingNext={saving}
      />
      <div className="nav-row">
        <button className="btn-back" onClick={handleBack}>← Indietro</button>
        <button className="btn-back" disabled={resetting} onClick={handleRestart}>{resetting ? 'Reset...' : 'Ricomincia'}</button>
      </div>
    </div>
  );
}
