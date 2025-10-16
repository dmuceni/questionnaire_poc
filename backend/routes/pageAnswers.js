const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { safeLoad, saveJson } = require('../utils/storage');

const DATA_PATH = path.join(__dirname, '../data/userData.json');

function loadUserData() {
  return safeLoad(DATA_PATH, {});
}
function saveUserData(data) {
  try { saveJson(DATA_PATH, data); return true; } catch { return false; }
}

// GET /api/pageAnswers/:userId/:cluster - Ottieni le risposte per pagine
router.get('/:userId/:cluster', (req, res) => {
  const { userId, cluster } = req.params;
  const userData = loadUserData();
  
  const userClusterData = userData[userId]?.[cluster] || {};
  const pageAnswers = userClusterData.pageAnswers || {};
  
  res.json({ pageAnswers });
});

// POST /api/pageAnswers/:userId/:cluster/reset - Reset di tutte le risposte
router.post('/:userId/:cluster/reset', (req, res) => {
  const { userId, cluster } = req.params;
  const userData = loadUserData();
  
  if (userData[userId] && userData[userId][cluster]) {
    userData[userId][cluster].pageAnswers = {};
    userData[userId][cluster].lastUpdated = new Date().toISOString();
    
    if (saveUserData(userData)) {
      res.json({ success: true });
    } else {
      res.status(500).json({ error: 'Errore nel reset' });
    }
  } else {
    res.json({ success: true }); // Non c'erano dati da resettare
  }
});

// POST /api/pageAnswers/:userId/:cluster/:pageId - Salva le risposte di una pagina
router.post('/:userId/:cluster/:pageId', (req, res) => {
  const { userId, cluster, pageId } = req.params;
  // Supporta sia { answers: {...} } sia payload diretto { questionId: value }
  let answers = req.body?.answers;
  if (!answers && req.body && typeof req.body === 'object') {
    // Se non c'è answers ma il body ha chiavi, assumiamo che sia già il dizionario
    const keys = Object.keys(req.body);
    if (keys.length > 0) {
      answers = req.body;
    }
  }
  if (!answers || typeof answers !== 'object') {
    return res.status(400).json({ error: 'Risposte non valide' });
  }
  
  const userData = loadUserData();
  
  // Inizializza la struttura se non existe
  if (!userData[userId]) userData[userId] = {};
  if (!userData[userId][cluster]) userData[userId][cluster] = {};
  if (!userData[userId][cluster].pageAnswers) userData[userId][cluster].pageAnswers = {};
  
  // Salva le risposte per la pagina specifica
  userData[userId][cluster].pageAnswers[pageId] = answers;
  
  // Aggiorna anche il timestamp
  userData[userId][cluster].lastUpdated = new Date().toISOString();
  
  if (saveUserData(userData)) {
    res.json({ success: true });
  } else {
    res.status(500).json({ error: 'Errore nel salvataggio' });
  }
});

// GET /api/pageAnswers/:userId/:cluster/:pageId - Ottieni le risposte di una pagina specifica
router.get('/:userId/:cluster/:pageId', (req, res) => {
  const { userId, cluster, pageId } = req.params;
  const userData = loadUserData();
  
  const pageAnswers = userData[userId]?.[cluster]?.pageAnswers?.[pageId] || {};
  
  res.json({ answers: pageAnswers });
});

module.exports = router;