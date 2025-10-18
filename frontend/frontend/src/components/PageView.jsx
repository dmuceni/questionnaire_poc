import React, { useState, useEffect } from 'react';
import Question from './Question';

// Renderizza una pagina con le sue domande e raccoglie risposte
export default function PageView({ page, initialAnswers, onSubmit, loadingNext }) {
  const [answers, setAnswers] = useState({});

  useEffect(() => {
    setAnswers(initialAnswers || {});
  }, [page?.id]);

  if (!page) return <div>Nessuna pagina</div>;

  const handleQuestionAnswer = (questionId, value) => {
    setAnswers(prev => ({ ...prev, [questionId]: value }));
  };

  const requiredQuestions = (page.questions || []).filter(q => q.required);
  const isComplete = requiredQuestions.every(q => answers[q.id] !== undefined && answers[q.id] !== null && answers[q.id] !== '');

  return (
    <div className="page-view">
      <h2>{page.title}</h2>
      {page.description && <p className="page-desc">{page.description}</p>}
      {(page.questions || []).map(q => (
        <Question key={q.id} question={q} onAnswer={(val) => handleQuestionAnswer(q.id, val)} />
      ))}
      <div className="nav-row">
        <button className="btn-next" disabled={!isComplete || loadingNext} onClick={() => onSubmit(answers)}>
          {page.isLast || page.nextPage === null ? 'Completa' : 'Continua'}
        </button>
      </div>
    </div>
  );
}
