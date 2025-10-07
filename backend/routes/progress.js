// backend/routes/progress.js - usa la stessa logica del frontend
const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

const CMS_PATH = path.join(__dirname, '../data/cms.json');
const USER_DATA_PATH = path.join(__dirname, '../data/userData.json');

function safeLoad(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fallback; }
}

// Stessa logica di QuestionnaireLoader.js
function buildFullPath(questions, answers) {
  const map = new Map((questions || []).map(q => [q.id, q]));
  const startId = questions?.[0]?.id;
  
  if (!startId) return { path: [], endReached: false };
  
  // Se non ci sono risposte, ritorna solo la prima domanda
  if (Object.keys(answers).length === 0) {
    return { path: [startId], endReached: false };
  }
  
  const path = [];
  let currentId = startId;
  let endReached = false;
  const visited = new Set();
  let safety = 0;
  
  while (currentId && !visited.has(currentId) && safety++ < 200) {
    path.push(currentId);
    visited.add(currentId);
    const q = map.get(currentId);
    
    if (!q?.next) { 
      endReached = true; 
      break; 
    }
    
    const ans = answers[currentId];
    
    // Se non c'è risposta, fermati qui
    if (ans === undefined) {
      break;
    }
    
    let nextId = null;
    if (typeof q.next === 'string') {
      nextId = q.next;
    } else if (typeof q.next === 'object') {
      nextId = q.next[ans] ?? q.next.default ?? null;
    }
    
    if (!nextId || !map.has(nextId)) { 
      endReached = true; 
      break; 
    }
    currentId = nextId;
  }
  
  return { path, endReached };
}

function computeProgress(questions, answers, completed) {
  if (completed) return 100;
  if (!Array.isArray(questions) || questions.length === 0) return 0;
  
  // Usa sempre il totale delle domande del questionario
  const totalQuestions = questions.length;
  const answeredCount = Object.keys(answers).filter(id => 
    questions.some(q => q.id === id)
  ).length;
  
  const percentage = Math.round((answeredCount / totalQuestions) * 100);
  return completed ? 100 : Math.min(percentage, 99);
}

router.get('/:userId', (req, res) => {
  try {
    const userId = req.params.userId;
    const cms = safeLoad(CMS_PATH, { clusters: {} });
    const users = safeLoad(USER_DATA_PATH, {});
    const answersByCluster = users[userId]?.answers || {};
    const clusters = cms.clusters || {};

    const result = Object.entries(clusters).map(([clusterKey, data]) => {
      const questions = data.questionnaire || [];
      const clusterAnswers = answersByCluster[clusterKey] || {};
      
      // Usa la stessa logica del frontend
      const { path, endReached } = buildFullPath(questions, clusterAnswers);
      const allAnsweredOnPath = path.every(id => clusterAnswers[id] !== undefined);
      const completed = endReached && allAnsweredOnPath;
      
      return {
        cluster: clusterKey,
        title: data.title || clusterKey,
        percent: computeProgress(questions, clusterAnswers, completed)
      };
    });

    res.json(result);
  } catch {
    res.json([]);
  }
});

module.exports = router;