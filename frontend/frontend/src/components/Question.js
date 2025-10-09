import React, { useEffect, useState } from 'react';
import './Question.css';

const Question = ({ question, onAnswer }) => {
  const getRatingMinValue = () => {
    if (typeof question?.minScale === 'number') {
      return question.minScale;
    }

    return 0;
  };

  const getRatingDefaultValue = () => {
    if (typeof question?.defaultValue === 'number') {
      return question.defaultValue;
    }

    return getRatingMinValue();
  };

  const [selectedValue, setSelectedValue] = useState(() => (
    question?.type === 'rating' ? getRatingDefaultValue() : null
  ));
  const [inputValue, setInputValue] = useState('');

  const handleAnswer = (value) => {
    setSelectedValue(value);
    onAnswer(value);
  };

  useEffect(() => {
    if (question?.type === 'rating') {
      setSelectedValue(getRatingDefaultValue());
    } else {
      setSelectedValue(null);
    }
  }, [question]);

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
    const minScale = getRatingMinValue();
    const maxScale = question.scale || 5;
    const scaleValues = Array.from(
      { length: maxScale - minScale + 1 },
      (_, i) => minScale + i
    );
    const currentValue = selectedValue ?? minScale;

    const updateValue = (value) => {
      const clamped = Math.min(Math.max(value, minScale), maxScale);
      handleAnswer(clamped);
    };

    const decrement = () => {
      updateValue(currentValue - 1);
    };

    const increment = () => {
      updateValue(currentValue + 1);
    };

    return (
      <div className="question-card">
        <h2 className="question-text">{question.text}</h2>
        <div className="scale-interaction">
          <button
            type="button"
            className="scale-button"
            onClick={decrement}
            disabled={currentValue <= minScale}
            aria-label="Diminuisci valore"
          >
            <span className="scale-button-symbol">−</span>
          </button>

          <div className="scale-slider-wrapper">
            <input
              type="range"
              min={minScale}
              max={maxScale}
              value={currentValue}
              className="scale-slider"
              onChange={(event) => updateValue(Number(event.target.value))}
            />

            <div className="scale-ticks" aria-hidden="true">
              {scaleValues.map((value) => (
                <span
                  key={value}
                  className={`scale-tick ${currentValue === value ? 'active' : ''}`}
                >
                  {value}
                </span>
              ))}
            </div>
          </div>

          <button
            type="button"
            className="scale-button"
            onClick={increment}
            disabled={currentValue >= maxScale}
            aria-label="Aumenta valore"
          >
            <span className="scale-button-symbol">+</span>
          </button>
        </div>

        {maxScale === 5 && (
          <div className="scale-labels">
            <span className="scale-label">Per niente</span>
            <span className="scale-label">Moltissimo</span>
          </div>
        )}

        {maxScale === 10 && (
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
