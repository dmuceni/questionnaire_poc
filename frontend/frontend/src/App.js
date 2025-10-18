import './App.css';
import React from 'react';
import { Routes, Route } from 'react-router-dom';
import QuestionnaireLoader from './components/QuestionnaireLoader';
import QuestionnairePageFlow from './components/QuestionnairePageFlow';
import CmsEditor from './pages/CmsEditor';
import QuestionnaireList from './pages/QuestionnaireList';

function App() {
  return (
    <div className="App">
      <Routes>
        <Route path="/" element={<QuestionnaireList />} />
        <Route path="/questionario/:cluster" element={
          <QuestionnaireLoader 
            onProgressChange={() => {
              // Notifica che le percentuali sono cambiate
              window.dispatchEvent(new CustomEvent('progressChanged'));
            }} 
          />
        } />
        <Route path="/questionario-pagine/:cluster" element={<QuestionnairePageFlow />} />
        <Route path="/cms-editor" element={<CmsEditor />} />
      </Routes>
    </div>
  );
}

export default App;