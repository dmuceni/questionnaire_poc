import React from 'react';
import './QuestionnaireLoader.css';

export default function ProgressBar({ value }) {
  return (
    <div className="progress">
      <div className="progress-title" style={{fontWeight: 'bold', fontSize: '1.1em', marginBottom: '4px'}}>Casa Mare</div>
      <div className="progress-text" style={{marginBottom: '8px'}}>{value}% completato</div>
      <div className="progress-bar-outer">
        <div className="progress-bar-inner" style={{ width: `${value}%` }} />
      </div>
    </div>
  );
}
