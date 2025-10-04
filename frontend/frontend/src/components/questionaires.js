import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';

const USER_ID = 'user_123';

const QuestionnaireList = () => {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    fetch(`/api/progress/${USER_ID}`)
      .then(r => r.json())
      .then(data => {
        setItems(data);
        setLoading(false);
      });
  }, []);

  if (loading) return <div>Caricamento...</div>;

  return (
    <div>
      <h1>Questionari</h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        {items.map(i => (
          <div key={i.cluster} style={{
            background: '#fff',
            border: '1px solid #ddd',
            borderRadius: 12,
            padding: 16
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3 style={{ margin: 0 }}>{i.title}</h3>
              <span style={{ fontWeight: 'bold', color: '#0057B8' }}>{i.percent}%</span>
            </div>
            <div style={{
              background: '#eee',
              height: 10,
              borderRadius: 6,
              overflow: 'hidden',
              margin: '8px 0 12px'
            }}>
              <div style={{
                width: `${i.percent}%`,
                background: '#0057B8',
                height: '100%',
                transition: 'width .3s'
              }} />
            </div>
            <button
              onClick={() => navigate(`/questionario/${i.cluster}`)}
              style={{
                padding: '10px 20px',
                background: '#0057B8',
                color: '#fff',
                border: 'none',
                borderRadius: 8,
                fontWeight: 'bold',
                cursor: 'pointer',
                width: '100%'
              }}
            >
              Apri
            </button>
          </div>
        ))}
      </div>
    </div>
  );
};

export default QuestionnaireList;