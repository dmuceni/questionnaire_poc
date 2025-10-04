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

function buildPath(questions, answers) {
  const map = new Map((questions || []).map(q => [q.id, q]));
  const startId = questions?.[0]?.id;
  const path = [];
  let endReached = false;
  if (!startId) return { path, endReached };
  const visited = new Set();
  let id = startId;
  let safety = 0;
  while (id && !visited.has(id) && safety++ < 200) {
    path.push(id);
    visited.add(id);
    const q = map.get(id);
    const ans = answers[id];
    if (!q?.next) { endReached = true; break; }
    if (ans === undefined) break;
    const nextId = getNextId(q, ans);
    if (!nextId || !map.has(nextId)) { endReached = true; break; }
    id = nextId;
  }
  return { path, endReached };
}

function computeProgress(questions, answers, currentStack, completed) {
  if (completed) return 100;
  if (!Array.isArray(questions) || questions.length === 0) return 0;
  
  // Conta il numero totale di domande possibili nel questionario
  const totalQuestions = questions.length;
  
  // Conta quante domande hanno una risposta
  const answeredCount = Object.keys(answers).filter(id => 
    questions.some(q => q.id === id)
  ).length;
  
  // Percentuale basata sul totale delle domande del questionario
  const percentage = Math.round((answeredCount / totalQuestions) * 100);
  
  return completed ? 100 : Math.min(percentage, 99);
}

const QuestionnaireLoader = () => {
  const { cluster } = useParams();
  const navigate = useNavigate();
  const [questions, setQuestions] = useState([]);
  const [answers, setAnswers] = useState({});
  const [stack, setStack] = useState([]); // array di id domande visitate in ordine
  const [currentId, setCurrentId] = useState(null);
  const [completed, setCompleted] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!cluster) {
      setLoading(false);
      navigate('/');
      return;
    }
    setLoading(true);
    setError('');
    Promise.all([
      fetch(`/api/questionnaire/${cluster}`),
      fetch(`/api/userAnswers/${USER_ID}/${cluster}`)
    ])
      .then(async ([qsRes, ansRes]) => {
        if (!qsRes.ok) throw new Error('Questionario non disponibile');
        if (!ansRes.ok) throw new Error('Risposte non disponibili');
        const qs = await qsRes.json();
        const userData = await ansRes.json();
        const a = userData?.answers || {};
        setQuestions(Array.isArray(qs) ? qs : []);
        setAnswers(a);

        const { path, endReached } = buildPath(qs || [], a);
        const pathNonVuoto = path.length > 0 ? path : (qs?.[0]?.id ? [qs[0].id] : []);
        setStack(pathNonVuoto);
        setCurrentId(pathNonVuoto[pathNonVuoto.length - 1] || null);
        const allAnsweredOnPath = path.every(id => a[id] !== undefined);
        setCompleted(endReached && allAnsweredOnPath);
        setLoading(false);
      })
      .catch(() => {
        setError('Errore di caricamento');
        setLoading(false);
      });
  }, [cluster, navigate]);

  const saveAnswers = (newAnswers) => {
    fetch(`/api/userAnswers/${USER_ID}/${cluster}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ answers: newAnswers })
    }).catch(() => {});
  };

  const handleAnswer = (questionId, answerValue) => {
    // se sto rispondendo a una domanda nel mezzo del percorso, tronco stack e risposte a valle
    const idxInStack = stack.indexOf(questionId);
    let trimmedAnswers = { ...answers };
    if (idxInStack !== -1 && idxInStack < stack.length - 1) {
      const toRemove = stack.slice(idxInStack + 1);
      toRemove.forEach(id => { delete trimmedAnswers[id]; });
    }
    trimmedAnswers[questionId] = answerValue;
    setAnswers(trimmedAnswers);

    const q = questions.find(qq => qq.id === questionId);
    const nextId = getNextId(q, answerValue);

    if (nextId && questions.some(qq => qq.id === nextId)) {
      const newStack = [...stack.slice(0, idxInStack + 1), nextId];
      setStack(newStack);
      setCurrentId(nextId);
      setCompleted(false);
    } else {
      // fine flusso
      setStack(stack.slice(0, idxInStack + 1));
      setCompleted(true);
    }

    saveAnswers(trimmedAnswers);
  };

  const handleBack = () => {
    if (!stack.length) {
      navigate('/');
      return;
    }
    if (stack.length === 1) {
      navigate('/');
      return;
    }
    const newStack = stack.slice(0, -1);
    setStack(newStack);
    setCurrentId(newStack[newStack.length - 1] || null);
    setCompleted(false);
  };

  if (loading) return <div>Caricamento...</div>;
  if (error) return (
    <div>
      <p>{error}</p>
      <button className="btn-back" onClick={() => navigate('/')}>Torna all’elenco</button>
    </div>
  );

  if (!questions.length) {
    return (
      <div>
        <p>Nessuna domanda disponibile.</p>
        <button className="btn-back" onClick={() => navigate('/')}>Torna all’elenco</button>
      </div>
    );
  }

  const progress = computeProgress(questions, answers, stack, completed);

  if (completed) {
    return (
      <div className="completed-wrap">
        <div className="progress">
          <div className="progress-bar-outer">
            <div className="progress-bar-inner" />
          </div>
          <div className="progress-text">100% completato</div>
        </div>
        <h2>Questionario completato</h2>
        <button className="btn-back" onClick={() => navigate('/')}>
          Torna all'elenco
        </button>
      </div>
    );
  }

  const currentQuestion = questions.find(q => q.id === currentId) || questions[0];

  return (
    <div>
      <div className="progress">
        <div className="progress-bar-outer">
          <div className="progress-bar-inner" style={{ width: `${progress}%` }} />
        </div>
        <div className="progress-text">{progress}% completato</div>
      </div>

      {currentQuestion && (
        <>
          <Question
            question={currentQuestion}
            onAnswer={val => handleAnswer(currentQuestion.id, val)}
          />
          <div className="nav-row">
            <button className="btn-back" onClick={handleBack}>
              ← Indietro
            </button>
          </div>
        </>
      )}
    </div>
  );
};

export default QuestionnaireLoader;
