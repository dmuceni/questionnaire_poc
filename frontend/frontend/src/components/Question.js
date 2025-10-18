import React, { useEffect, useState, useCallback } from 'react';
import './Question.css';

const Question = ({ question, onAnswer }) => {
  const getRatingMinValue = useCallback(() => {
    if (typeof question?.minScale === 'number') return question.minScale;
    return 0;
  }, [question?.minScale]);

  const getRatingDefaultValue = useCallback(() => {
    if (typeof question?.defaultValue === 'number') return question.defaultValue;
    return getRatingMinValue();
  }, [question?.defaultValue, getRatingMinValue]);

  const [selectedValue, setSelectedValue] = useState(() => (
    question?.type === 'rating' ? getRatingDefaultValue() : null
  ));
  // Stato di ricerca per grouped multiple choice (isolato per domanda corrente)
  const [groupedSearch, setGroupedSearch] = useState('');

  const handleAnswer = (value) => {
    setSelectedValue(value);
    onAnswer(value);
  };

  useEffect(() => {
    if (question?.type === 'rating') setSelectedValue(getRatingDefaultValue());
    else setSelectedValue(null);
  }, [question, getRatingDefaultValue]);

  // Funzioni input text rimosse perché non necessarie (domanda open salva onChange)

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

  const renderMultipleChoice = () => {
    return (
      <div className="question-card">
        <h2 className="question-text">{question.text}</h2>
        <div className="multiple-choice-options">
          {question.options?.map((option) => {
            const isSelected = Array.isArray(selectedValue) && selectedValue.includes(option.id);
            return (
              <label key={option.id} className="multiple-choice-option">
                <input
                  type="checkbox"
                  checked={isSelected}
                  onChange={(e) => {
                    const currentSelection = Array.isArray(selectedValue) ? [...selectedValue] : [];
                    if (e.target.checked) {
                      // Aggiungi l'opzione se non è già selezionata
                      if (!currentSelection.includes(option.id)) {
                        currentSelection.push(option.id);
                      }
                    } else {
                      // Rimuovi l'opzione se deselezionata
                      const index = currentSelection.indexOf(option.id);
                      if (index > -1) {
                        currentSelection.splice(index, 1);
                      }
                    }
                    handleAnswer(currentSelection);
                  }}
                />
                <span className="checkmark"></span>
                {option.label}
              </label>
            );
          })}
        </div>
      </div>
    );
  };

  const renderGroupedMultipleChoice = () => {
    const groups = question.groups || [];
    const maxSel = question.maxSelections || Infinity;
    const currentSelection = Array.isArray(selectedValue) ? selectedValue : [];

    const toggle = (id) => {
      let next = [...currentSelection];
      const idx = next.indexOf(id);
      if (idx >= 0) { next.splice(idx,1); }
      else if (next.length < maxSel) { next.push(id); }
      handleAnswer(next);
    };

    const filteredGroups = groups.map(g => ({
      ...g,
      options: g.options.filter(o => !groupedSearch || o.label.toLowerCase().includes(groupedSearch.toLowerCase()))
    })).filter(g => g.options.length > 0);

    return (
      <div className="question-card">
        <h2 className="question-text">{question.text}</h2>
        {question.searchEnabled && (
          <input
            type="text"
            placeholder="Cerca..."
            className="grouped-search"
            value={groupedSearch}
            onChange={e => setGroupedSearch(e.target.value)}
          />
        )}
        <div className="grouped-mc-wrapper">
          {filteredGroups.map(g => (
            <div key={g.id} className="group-block">
              <div className="group-title">{g.label}</div>
              <div className="group-options">
                {g.options.map(opt => {
                  const sel = currentSelection.includes(opt.id);
                  return (
                    <button
                      type="button"
                      key={opt.id}
                      className={`group-option ${sel ? 'selected' : ''}`}
                      onClick={() => toggle(opt.id)}
                      disabled={!sel && currentSelection.length >= maxSel}
                    >
                      {opt.label}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
        {maxSel !== Infinity && (
          <div className="selection-hint">{currentSelection.length}/{maxSel} selezionate</div>
        )}
      </div>
    );
  };

  return (
    <div className="question-container">
      {question.type === 'rating' && renderRatingScale()}
      {question.type === 'card' && renderCardOptions()}
      {question.type === 'open' && renderOpenQuestion()}
      {question.type === 'multiple_choice' && renderMultipleChoice()}
      {question.type === 'multiple_choice_grouped' && renderGroupedMultipleChoice()}
    </div>
  );
};

export default Question;
