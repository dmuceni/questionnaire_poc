import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './QuestionnaireList.css';

const USER_ID = 'user_123';

const QuestionnaireList = () => {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    fetch(`/api/progress/${USER_ID}`)
      .then(r => r.ok ? r.json() : [])
      .then(data => {
        setItems(Array.isArray(data) ? data : []);
        setLoading(false);
      })
      .catch(() => {
        setItems([]);
        setLoading(false);
      });
  }, []);

  const handleRestart = async (cluster) => {
    const resp = await fetch(`/api/userAnswers/${USER_ID}/reset/${cluster}`, { method: 'POST' });
    if (!resp.ok) {
      console.error('Reset fallito');
      return;
    }
    setItems(prev => prev.map(i => i.cluster === cluster ? { ...i, percent: 0 } : i));
    navigate(`/questionario/${cluster}`);
  };

  if (loading) return <div className="loading">Caricamento...</div>;

  return (
    <div className="ql-wrap">
      <div className="ql-header">
        <h1>Questionari</h1>
      </div>
      
      <div className="ql-list">
        {items.map(i => (
          <div key={i.cluster} className={`ql-card ${i.cluster.replace('_', '-')}`}>
            <div className="ql-card-header">
              <h3 className="ql-title">{i.title}</h3>
              <span className={`ql-percent ${i.percent === 100 ? 'completed' : ''}`}>
                {i.percent}%
              </span>
            </div>
            
            <div className="ql-progress">
              <div className="ql-progress-bar" style={{ width: `${i.percent}%` }} />
            </div>
            
            <div className="ql-actions">
              {i.percent < 100 && (
                <button 
                  className="btn btn-primary" 
                  onClick={() => navigate(`/questionario/${i.cluster}`)}
                >
                  Continua
                </button>
              )}
              {i.percent === 100 && (
                <button 
                  className="btn btn-danger" 
                  onClick={() => handleRestart(i.cluster)}
                >
                  Ricomincia
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default QuestionnaireList;