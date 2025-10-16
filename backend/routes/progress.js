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

// ===================== Calcolo Progresso Pagine (DATA-DRIVEN) =====================
// Questa implementazione non dipende da ID o mapping hardcoded e deriva tutto
// dalla struttura delle pagine (ordine) e dal loro `conditionalRouting`.

// Valuta una condizione di routing contro le risposte aggregate
function evaluateCondition(condition, flatAnswers) {
  const userValue = flatAnswers[condition.questionId];
  if (userValue === undefined) return false;
  const userStr = String(userValue);
  const expected = String(condition.value);
  // Support sia 'operatorType' (nuovo) che 'operator' (legacy) per retrocompatibilità JSON
  const op = condition.operatorType || condition.operator;
  if (op === '==' || op === '!=') {
    return op === '==' ? userStr === expected : userStr !== expected;
  }
  // Operatori numerici
  const uNum = Number(userStr);
  const eNum = Number(expected);
  if (Number.isNaN(uNum) || Number.isNaN(eNum)) return false;
  switch (op) {
    case '>': return uNum > eNum;
    case '>=': return uNum >= eNum;
    case '<': return uNum < eNum;
    case '<=': return uNum <= eNum;
    default: return false;
  }
}

// Restituisce gli indici delle pagine raggiungibili da una pagina con conditionalRouting
function resolveRoutingTargets(routing, pages, flatAnswers) {
  if (!routing) return [];
  // Ordina regole per priority (numero più basso = priorità maggiore)
  const rules = [...(routing.rules || [])].sort((a,b) => (a.priority ?? 0) - (b.priority ?? 0));
  const matchedPages = rules.filter(r => evaluateCondition(r.condition, flatAnswers)).map(r => r.nextPage);
  const targets = new Set();
  matchedPages.forEach(pid => targets.add(pid));
  // Aggiungi comunque defaultAction (se non è 'complete') perché dopo le pagine condizionali si prosegue lì
  if (routing.defaultAction && routing.defaultAction !== 'complete') {
    targets.add(routing.defaultAction);
  }
  // Mappa in indici validi
  return [...targets].map(id => pages.findIndex(p => p.id === id)).filter(i => i >= 0);
}

// Calcola l'insieme di pagine raggiungibili via BFS
function computeReachablePageIndices(pages, flatAnswers) {
  if (!Array.isArray(pages) || pages.length === 0) return new Set();
  const visited = new Set();
  const queue = [0]; // parte sempre dalla prima pagina
  while (queue.length) {
    const idx = queue.shift();
    if (idx < 0 || idx >= pages.length || visited.has(idx)) continue;
    visited.add(idx);
    const page = pages[idx];
    if (page && page.conditionalRouting) {
      const targets = resolveRoutingTargets(page.conditionalRouting, pages, flatAnswers);
      targets.forEach(t => { if (!visited.has(t)) queue.push(t); });
    } else {
      // Progressione sequenziale se non c'è routing definito
      const next = idx + 1;
      if (next < pages.length) queue.push(next);
    }
  }
  return visited;
}

// Calcola progresso: required answered / required totali nelle pagine raggiungibili
function calculatePageProgress(pages, pageAnswers) {
  if (!Array.isArray(pages) || pages.length === 0) return 0;

  // Flatten answers per valutare condizioni (questionId -> value)
  const flatAnswers = Object.values(pageAnswers || {}).reduce((acc, answersObj) => {
    Object.entries(answersObj || {}).forEach(([qid, v]) => { acc[qid] = v; });
    return acc;
  }, {});

  const reachable = computeReachablePageIndices(pages, flatAnswers);
  if (reachable.size === 0) return 0;

  let totalRequired = 0;
  let answeredRequired = 0;

  for (const idx of reachable) {
    const page = pages[idx];
    if (!page) continue;
    const reqQuestions = (page.questions || []).filter(q => q.required === true);
    if (reqQuestions.length === 0) continue;
    totalRequired += reqQuestions.length;
    const saved = pageAnswers[page.id] || {};
    answeredRequired += reqQuestions.filter(q => saved[q.id] !== undefined).length;
  }

  if (totalRequired === 0) return 0;
  const pct = Math.round((answeredRequired / totalRequired) * 100);
  // Considera completo se tutte le required risposte; altrimenti limita a 99
  return answeredRequired === totalRequired ? 100 : Math.min(pct, 99);
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

    // Debug logging per diagnosi elenco vuoto
    console.log('[progress] userId=', userId);
    console.log('[progress] cluster keys=', Object.keys(clusters));
    console.log('[progress] has pageAnswers clusters=', Object.keys(userPageAnswers));

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
        questionnaireTitle: data.questionnaireTitle,
        questionnaireSubtitle: data.questionnaireSubtitle,
        percent
      };
    });

    res.json(result);
    console.log('[progress] result length=', result.length);
  } catch (error) {
    console.error('Errore nel calcolo del progresso:', error);
    res.json([]);
  }
});

module.exports = router;