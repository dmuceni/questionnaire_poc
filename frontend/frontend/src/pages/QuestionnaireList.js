import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './QuestionnaireList.css';
import { resetAllForCluster, fetchPages } from '../api';

const USER_ID = 'user_123';

const QuestionnaireList = () => {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  const loadProgress = () => {
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
  };

  useEffect(() => {
    loadProgress();
  }, []);

  useEffect(() => {
    const handleFocus = () => {
      console.log('🔄 Refresh percentuali lista questionari');
      loadProgress();
    };
    
    window.addEventListener('focus', handleFocus);
    return () => window.removeEventListener('focus', handleFocus);
  }, []);

  useEffect(() => {
    const handleProgressChange = () => {
      console.log('🔄 Aggiornamento percentuali richiesto');
      loadProgress();
    };
    
    window.addEventListener('progressChanged', handleProgressChange);
    return () => window.removeEventListener('progressChanged', handleProgressChange);
  }, []);

  async function clusterHasPages(cluster) {
    try {
      const resp = await fetchPages(cluster);
      return Array.isArray(resp?.pages) && resp.pages.length > 0;
    } catch {
      return false;
    }
  }

  const handleContinue = async (cluster) => {
    // Se il cluster ha pagine, mandiamo direttamente al flusso a pagine
    const hasPages = await clusterHasPages(cluster);
    navigate(hasPages ? `/questionario-pagine/${cluster}` : `/questionario/${cluster}`);
  };

  const handleRestart = async (cluster) => {
    try {
      await resetAllForCluster(cluster); // svuota sia risposte classiche che pagine
    } catch (e) {
      console.error('Reset fallito', e);
      return;
    }
    setItems(prev => prev.map(i => i.cluster === cluster ? { ...i, percent: 0 } : i));
    window.dispatchEvent(new CustomEvent('progressChanged'));
    const hasPages = await clusterHasPages(cluster);
    navigate(hasPages ? `/questionario-pagine/${cluster}` : `/questionario/${cluster}`);
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
                  onClick={() => handleContinue(i.cluster)}
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