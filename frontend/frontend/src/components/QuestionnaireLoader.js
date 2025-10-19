import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import Question from './Question';
import './QuestionnaireLoader.css';

const USER_ID = 'user_123';

function getNextId(q, ansVal) {
  if (!q || !q.next) return null;
  if (typeof q.next === 'string') return q.next;
  if (typeof q.next === 'object') return q.next[ansVal] ?? q.next.default ?? null;
  return null;
}

function buildFullPath(questions, answers) {
  const map = new Map((questions || []).map(q => [q.id, q]));
  const startId = questions?.[0]?.id;
  if (!startId) return { path: [], endReached: false };
  if (Object.keys(answers).length === 0) return { path: [startId], endReached: false };
  const path = []; let currentId = startId; let endReached = false; const visited = new Set(); let safety = 0;
  while (currentId && !visited.has(currentId) && safety++ < 200) {
    path.push(currentId); visited.add(currentId); const q = map.get(currentId);
    if (!q?.next) { endReached = true; break; }
    const ans = answers[currentId]; if (ans === undefined) break;
    let nextId = null;
    if (typeof q.next === 'string') nextId = q.next; else if (typeof q.next === 'object') nextId = q.next[ans] ?? q.next.default ?? null;
    if (!nextId || !map.has(nextId)) { endReached = true; break; }
    currentId = nextId;
  }
  return { path, endReached };
}

function computeProgress(questions, answers, stack, completed) {
  if (completed) return 100;
  if (!Array.isArray(questions) || questions.length === 0) return 0;
  const totalQuestions = questions.length;
  const answeredCount = Object.keys(answers).filter(id => questions.some(q => q.id === id)).length;
  const percentage = Math.round((answeredCount / totalQuestions) * 100);
  return completed ? 100 : Math.min(percentage, 99);
}

const QuestionnaireLoader = ({ onProgressChange }) => {
  const { cluster } = useParams();
  const navigate = useNavigate();
  const [questions, setQuestions] = useState([]);
  const [answers, setAnswers] = useState({});
  const [stack, setStack] = useState([]);
  const [currentId, setCurrentId] = useState(null);
  const [completed, setCompleted] = useState(false);
  const [loading, setLoading] = useState(true);
  const [clusterMeta, setClusterMeta] = useState({ title: '', questionnaireTitle: '', questionnaireSubtitle: '' });
  const [error, setError] = useState('');

  useEffect(() => {
    if (!cluster) { setLoading(false); navigate('/'); return; }
    setLoading(true); setError('');
    Promise.all([
      fetch(`/api/questionnaire/${cluster}`),
      fetch(`/api/userAnswers/${USER_ID}/${cluster}`),
      fetch(`/api/progress/${USER_ID}`)
    ])
      .then(async ([qsRes, ansRes, progressRes]) => {
        if (!qsRes.ok) throw new Error('Questionario non disponibile');
        if (!ansRes.ok) throw new Error('Risposte non disponibili');
        if (progressRes.ok) {
          const allProgress = await progressRes.json();
          const meta = allProgress.find(p => p.cluster === cluster);
          if (meta) setClusterMeta({
            title: meta.title || '',
            questionnaireTitle: meta.questionnaireTitle || meta.title || '',
            questionnaireSubtitle: meta.questionnaireSubtitle || ''
          });
        }
        const qs = await qsRes.json();
        // Se il questionario è vuoto, potrebbe essere un cluster a Pagine -> redirect
        if (!Array.isArray(qs) || qs.length === 0) {
          try {
            const pagesResp = await fetch(`/api/pages/${cluster}`);
            if (pagesResp.ok) {
              const pagesData = await pagesResp.json();
              if (Array.isArray(pagesData.pages) && pagesData.pages.length > 0) {
                navigate(`/questionario-pagine/${cluster}`, { replace: true });
                return;
              }
            }
          } catch (_) { /* ignora e prosegue mostrando messaggio vuoto */ }
        }

        const userData = await ansRes.json();
        const a = userData?.answers || {};
        setQuestions(Array.isArray(qs) ? qs : []);
        setAnswers(a);
        const { path, endReached } = buildFullPath(qs || [], a);
        const pathNonVuoto = path.length > 0 ? path : (qs?.[0]?.id ? [qs[0].id] : []);
        setStack(pathNonVuoto);
        setCurrentId(pathNonVuoto[pathNonVuoto.length - 1] || null);
        const allAnsweredOnPath = path.every(id => a[id] !== undefined);
        setCompleted(endReached && allAnsweredOnPath);
        setLoading(false);
      })
      .catch((e) => { setError('Errore di caricamento'); setLoading(false); });
  }, [cluster, navigate]);

  const saveAnswers = (newAnswers) => {
    fetch(`/api/userAnswers/${USER_ID}/${cluster}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ answers: newAnswers })
    }).then(() => { onProgressChange && onProgressChange(); }).catch(() => {});
  };

  const handleAnswer = (questionId, answerValue) => {
    const idxInStack = stack.indexOf(questionId);
    let trimmedAnswers = { ...answers };
    if (idxInStack !== -1 && idxInStack < stack.length - 1) {
      const toRemove = stack.slice(idxInStack + 1); toRemove.forEach(id => { delete trimmedAnswers[id]; });
    }
    trimmedAnswers[questionId] = answerValue; setAnswers(trimmedAnswers);
    const q = questions.find(qq => qq.id === questionId); const nextId = getNextId(q, answerValue);
    if (nextId && questions.some(qq => qq.id === nextId)) {
      const newStack = [...stack.slice(0, idxInStack + 1), nextId]; setStack(newStack); setCurrentId(nextId); setCompleted(false);
    } else { setStack(stack.slice(0, idxInStack + 1)); setCompleted(true); }
    saveAnswers(trimmedAnswers);
  };

  const handleBack = () => {
    if (!stack.length || stack.length === 1) { navigate('/'); return; }
    const newStack = stack.slice(0, -1); const previousQuestionId = newStack[newStack.length - 1];
    const updatedAnswers = { ...answers };
    if (previousQuestionId && updatedAnswers[previousQuestionId] !== undefined) {
      delete updatedAnswers[previousQuestionId]; setAnswers(updatedAnswers);
      fetch(`/api/userAnswers/${USER_ID}/${cluster}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ answers: updatedAnswers })
      }).then(() => { window.dispatchEvent(new CustomEvent('progressChanged')); }).catch(() => {});
    }
    setStack(newStack); setCurrentId(previousQuestionId || null); setCompleted(false);
  };

  if (loading) return <div>Caricamento...</div>;
  if (error) return <div><p>{error}</p><button className="btn-back" onClick={() => navigate('/')}>Torna all’elenco</button></div>;
  if (!questions.length) return <div><p>Nessuna domanda disponibile per questo cluster. Potrebbe usare il flusso a pagine.</p><button className="btn-back" onClick={() => navigate(`/questionario-pagine/${cluster}`)}>Vai al flusso a pagine</button> <button className="btn-back" onClick={() => navigate('/')}>Torna all’elenco</button></div>;
  const progress = computeProgress(questions, answers, stack, completed);
  if (completed) return <div className="completed-wrap"><div className="progress"><div className="progress-bar-outer"><div className="progress-bar-inner" /></div><div className="progress-text">100% completato</div></div><h2>Questionario completato</h2><button className="btn-back" onClick={() => navigate('/')}>Torna all'elenco</button></div>;
  const currentQuestion = questions.find(q => q.id === currentId) || questions[0];
  const headerTitle = clusterMeta.questionnaireTitle || clusterMeta.title || '';
  const headerSubtitle = clusterMeta.questionnaireSubtitle || '';
  return (
    <div>
      <div className="q-flow-topbar">
        <div className="q-flow-header">
          <div className="q-flow-header-inner">
            {headerTitle && <h1>{headerTitle}</h1>}
            {headerSubtitle && <p>{headerSubtitle}</p>}
          </div>
        </div>
        <div className="progress"><div className="progress-bar-outer"><div className="progress-bar-inner" style={{ width: `${progress}%` }} /></div><div className="progress-text">{progress}% completato</div></div>
      </div>
      <div className="q-flow-container">
        {currentQuestion && (
          <>
            <Question question={currentQuestion} onAnswer={val => handleAnswer(currentQuestion.id, val)} />
            <div className="nav-row"><button className="btn-back" onClick={handleBack}>← Indietro</button></div>
          </>
        )}
      </div>
    </div>
  );
};

export default QuestionnaireLoader;
