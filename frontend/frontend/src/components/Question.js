import React, { useState } from 'react';
import './Question.css';

const Question = ({ question, onAnswer }) => {
  const [selectedValue, setSelectedValue] = useState(null);
  const [inputValue, setInputValue] = useState('');

  const handleAnswer = (value) => {
    setSelectedValue(value);
    onAnswer(value);
  };

  const handleInputChange = (e) => {
    setInputValue(e.target.value);
  };

  const handleInputSubmit = (e) => {
    e.preventDefault();
    if (inputValue.trim()) {
      onAnswer(inputValue.trim());
      setInputValue('');
    }
  };

  const renderRatingScale = () => {
    const scale = question.scale || 5;
    const options = Array.from({ length: scale }, (_, i) => i + 1);

    return (
      <div className="question-card">
        <h2 className="question-text">{question.text}</h2>

        <div className="rating-scale">
          {options.map((value) => (
            <div
              key={value}
              className={`rating-option ${selectedValue === value ? 'selected' : ''}`}
              onClick={() => handleAnswer(value)}
            >
              <div className="rating-circle">
                {value}
              </div>
              <div className="rating-label">
                {value}
              </div>
            </div>
          ))}
        </div>

        {scale === 5 && (
          <div className="scale-labels">
            <span className="scale-label">Per niente</span>
            <span className="scale-label">Moltissimo</span>
          </div>
        )}

        {scale === 10 && (
          <div className="scale-labels">
            <span className="scale-label">Per niente probabile</span>
            <span className="scale-label">Estremamente probabile</span>
          </div>
        )}
      </div>
    );
  };

  const renderCardOptions = () => {
    return (
      <div className="question-card">
        <h2 className="question-text">{question.text}</h2>
        <div className="card-options">
          {question.options?.map((option) => (
            <button
              key={option.id}
              className={`card-option ${selectedValue === option.id ? 'selected' : ''}`}
              onClick={() => handleAnswer(option.id)}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>
    );
  };

  const renderOpenQuestion = () => {
    return (
      <div className="question-card">
        <h2 className="question-text">{question.text}</h2>
        <div className="open-question-container">
          <textarea
            className="open-input"
            placeholder="Scrivi la tua risposta..."
            onChange={(e) => handleAnswer(e.target.value)}
          />
        </div>
      </div>
    );
  };

  return (
    <div className="question-container">
      {question.type === 'rating' && renderRatingScale()}
      {question.type === 'card' && renderCardOptions()}
      {question.type === 'open' && renderOpenQuestion()}
    </div>
  );
};

export default Question;
