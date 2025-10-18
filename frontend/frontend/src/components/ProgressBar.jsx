import React from 'react';
import './QuestionnaireLoader.css';

export default function ProgressBar({ value }) {
  return (
    <div className="progress">
      <div className="progress-bar-outer">
        <div className="progress-bar-inner" style={{ width: `${value}%` }} />
      </div>
      <div className="progress-text">{value}% completato</div>
    </div>
  );
}
