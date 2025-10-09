// backend/routes/progress.js - supporta sia il formato classico che le pagine
const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

const CMS_PATH = path.join(__dirname, '../data/cms.json');
const USER_DATA_PATH = path.join(__dirname, '../data/userData.json');

function safeLoad(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fallback; }
}

// Calcola il progresso per il formato a pagine
function calculatePageProgress(pages, pageAnswers) {
  if (!pages || pages.length === 0) return 0;
  
  let totalQuestions = 0;
  let answeredQuestions = 0;
  
  for (const page of pages) {
    for (const question of page.questions || []) {
      totalQuestions++;
      
      // Controlla se la domanda ha una risposta in qualsiasi pagina
      const hasAnswer = Object.values(pageAnswers).some(answers => 
        answers[question.id] !== undefined
      );
      
      if (hasAnswer) {
        answeredQuestions++;
      }
    }
  }
  
  if (totalQuestions === 0) return 0;
  return Math.round((answeredQuestions / totalQuestions) * 100);
}

// Stessa logica di QuestionnaireLoader.js per formato classico
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
    const userAnswers = users[userId]?.answers || {};
    const userPageAnswers = users[userId] || {};
    const clusters = cms.clusters || {};

    const result = Object.entries(clusters).map(([clusterKey, data]) => {
      let percent = 0;
      
      // Controlla se usa il nuovo formato a pagine
      if (data.pages && Array.isArray(data.pages)) {
        const pageAnswers = userPageAnswers[clusterKey]?.pageAnswers || {};
        percent = calculatePageProgress(data.pages, pageAnswers);
      } else {
        // Usa il formato classico
        const questions = data.questionnaire || [];
        const clusterAnswers = userAnswers[clusterKey] || {};
        
        const { path, endReached } = buildFullPath(questions, clusterAnswers);
        const allAnsweredOnPath = path.every(id => clusterAnswers[id] !== undefined);
        const completed = endReached && allAnsweredOnPath;
        
        percent = computeProgress(questions, clusterAnswers, completed);
      }
      
      return {
        cluster: clusterKey,
        title: data.title || clusterKey,
        percent
      };
    });

    res.json(result);
  } catch (error) {
    console.error('Errore nel calcolo del progresso:', error);
    res.json([]);
  }
});

module.exports = router;