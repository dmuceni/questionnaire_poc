import './App.css';
import React from 'react';
import { Routes, Route } from 'react-router-dom';
import QuestionnaireLoader from './components/QuestionnaireLoader';
import CmsEditor from './pages/CmsEditor';
import QuestionnaireList from './pages/QuestionnaireList';

function App() {
  return (
    <div className="App">
      <Routes>
        <Route path="/" element={<QuestionnaireList />} />
        <Route path="/questionario/:cluster" element={<QuestionnaireLoader />} />
        <Route path="/cms-editor" element={<CmsEditor />} />
      </Routes>
    </div>
  );
}

export default App;