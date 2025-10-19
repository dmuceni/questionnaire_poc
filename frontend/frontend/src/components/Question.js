import React, { useEffect, useState, useCallback } from 'react';
import './Question.css';

const Question = ({ question, onAnswer }) => {
  // Rimuove il focus dal titolo della pagina all'avvio
  useEffect(() => {
    const h2 = document.querySelector('h2.question-text');
    if (h2 && document.activeElement === h2) {
      h2.blur();
    }
  }, [question]);
  // Forzatura scala 0-5 indipendentemente dai dati forniti
  const getRatingMinValue = useCallback(() => 0, []);
  const getRatingMaxValue = useCallback(() => 5, []);
  const getRatingDefaultValue = useCallback(() => 0, []);

  const [selectedValue, setSelectedValue] = useState(() => {
    if (question?.type === 'rating') return getRatingDefaultValue();
    if (question?.type === 'multiple_choice' || question?.type === 'multiple_choice_grouped') return [];
    return null;
  });
  // Stato di ricerca per grouped multiple choice (isolato per domanda corrente)
  const [groupedSearch, setGroupedSearch] = useState('');
  // Stato tab attiva per grouped multiple choice (pagina calcio etc.)
  const [activeTab, setActiveTab] = useState(null);

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
  const maxScale = getRatingMaxValue();
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
      <div className="question-card rating-card" style={{position:'relative'}}>
        {question.gradientType && (
          <div style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            height: 8,
            borderRadius: '20px 20px 0 0',
            background: `linear-gradient(90deg, ${question.gradientType.from}, ${question.gradientType.to})`,
            zIndex: 1
          }} />
        )}
        <h2 className="question-text">{question.text}</h2>
        {question.subtitle && <p className="rating-subtitle">{question.subtitle}</p>}
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

        {/* Etichette estremi rimosse su richiesta */}
      </div>
    );
  };

  const renderCardOptions = () => {
    // Disposizione a tabella come le multiple_choice
    const optionRows = [];
    const opts = question.options || [];
    for (let i = 0; i < opts.length; i += 2) {
      optionRows.push(opts.slice(i, i + 2));
    }
    return (
      <div className="question-block">
        <h2 className="question-text plain">{question.text}</h2>
        <table className="mc-table">
          <tbody>
            {optionRows.map((row, idx) => (
              <tr key={idx}>
                <td colSpan={2} style={{padding:0}}>
                  <div className="mc-row" style={{display:'flex'}}>
                    {row.map((option) => {
                      const isSelected = selectedValue === option.id;
                      return (
                        <div key={option.id} style={{width:'50%'}}>
                          <div
                            className={`mc-card${isSelected ? ' selected' : ''}`}
                            style={{position:'relative'}} 
                            onClick={() => handleAnswer(option.id)}
                          >
                            <input
                              type="radio"
                              checked={isSelected}
                              style={{position: 'absolute', top: 12, right: 12}}
                            />
                            <div className="mc-label">{option.label}</div>
                          </div>
                        </div>
                      );
                    })}
                    {/* Se la riga ha solo una opzione, aggiungi una cella vuota per mantenere la struttura */}
                    {row.length < 2 && <div style={{width:'50%'}}></div>}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  };

  const renderOpenQuestion = () => {
    return (
      <div className="question-block">
        <h2 className="question-text plain">{question.text}</h2>
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
    // Raggruppa le opzioni a coppie per riga
    const optionRows = [];
    const opts = question.options || [];
    for (let i = 0; i < opts.length; i += 2) {
      optionRows.push(opts.slice(i, i + 2));
    }
    return (
      <div className="question-block">
        <h2 className="question-text plain">{question.text}</h2>
        <table className="mc-table">
          <tbody>
            {optionRows.map((row, idx) => (
              <tr key={idx}>
                <td colSpan={2} style={{padding:0}}>
                  <div className="mc-row" style={{display:'flex'}}>
                    {row.map((option) => {
                      const isSelected = Array.isArray(selectedValue) && selectedValue.includes(option.id);
                      return (
                        <div key={option.id} style={{width:'50%'}}>
                          <div
                            className={`mc-card${isSelected ? ' selected' : ''}`}
                            style={{position:'relative'}} 
                            onClick={() => {
                              const currentSelection = Array.isArray(selectedValue) ? [...selectedValue] : [];
                              if (!isSelected) {
                                currentSelection.push(option.id);
                              } else {
                                const index = currentSelection.indexOf(option.id);
                                if (index > -1) currentSelection.splice(index, 1);
                              }
                              handleAnswer(currentSelection);
                            }}
                          >
                            <input
                              type="checkbox"
                              checked={isSelected}
                              readOnly
                              className="mc-checkbox"
                              style={{position: 'absolute', top: 12, right: 12}}
                            />
                            <span className="mc-checkmark" style={{position: 'absolute', top: 12, right: 12}}></span>
                            <div className="mc-label">{option.label}</div>
                          </div>
                        </div>
                      );
                    })}
                    {/* Se la riga ha solo una opzione, aggiungi una cella vuota per mantenere la struttura */}
                    {row.length < 2 && <div style={{width:'50%'}}></div>}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  };

  const renderGroupedMultipleChoice = () => {
    const groups = question.groups || [];
    if (activeTab === null && groups.length > 0) {
      // inizializza tab attiva alla prima solo quando necessario
      setActiveTab(groups[0].id);
    }
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

  const visibleGroup = filteredGroups.find(g => g.id === activeTab) || filteredGroups[0];

    return (
      <div className="question-block grouped">
        <h2 className="question-text plain">{question.text}</h2>
        <div className="grouped-tabs variant-figma">
          {filteredGroups.map(g => {
            const isActive = g.id === activeTab;
            return (
              <button
                key={g.id}
                type="button"
                className={`group-tab ${isActive ? 'active' : ''}`}
                onClick={() => setActiveTab(g.id)}
                aria-pressed={isActive}
              >
                <span className="group-tab-label">{g.label}</span>
              </button>
            );
          })}
        </div>
        {question.searchEnabled && (
          <input
            type="text"
            placeholder="Cerca..."
            className="grouped-search"
            value={groupedSearch}
            onChange={e => setGroupedSearch(e.target.value)}
          />
        )}
  <div className="grouped-mc-wrapper single-group">
          {visibleGroup && (
            <div className="group-block">
              <div className="group-options">
                {visibleGroup.options.map(opt => {
                  const sel = currentSelection.includes(opt.id);
                  return (
                    <button
                      type="button"
                      key={opt.id}
                      className={`group-option ${sel ? 'selected' : ''}`}
                      onClick={() => toggle(opt.id)}
                      disabled={!sel && currentSelection.length >= maxSel}
                      style={{display:'flex',alignItems:'center',justifyContent:'space-between'}}
                    >
                      <span style={{display:'flex',alignItems:'center',gap:'10px'}}>
                        {opt.icon ? (
                          <img src={opt.icon} alt={opt.label + ' logo'} className="team-icon" style={{width:28,height:28,objectFit:'contain',borderRadius:'50%',background:'#fff',border:'1px solid #eee'}} />
                        ) : (
                          <span className="team-icon" aria-hidden="true">{opt.label.charAt(0).toUpperCase()}</span>
                        )}
                        <span className="team-name">{opt.label}</span>
                      </span>
                      <span className="option-checkbox" aria-hidden="true" style={{marginLeft:'auto',marginRight:0}}>
                        <input type="checkbox" checked={sel} readOnly style={{pointerEvents:'none',accentColor:'#1976d2',width:20,height:20}} />
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}
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
