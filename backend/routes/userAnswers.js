const express = require('express');
const router = express.Router();

const fs = require('fs');
const path = require('path');

const USER_DATA_PATH = path.join(__dirname, '../data/userData.json');
const CMS_PATH = path.join(__dirname, '../data/cms.json');

function safeLoad(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fallback; }
}
function saveJson(p, data) {
  fs.writeFileSync(p, JSON.stringify(data, null, 2), 'utf8');
}

// GET risposte per cluster
router.get('/:userId/:cluster', (req, res) => {
  try {
    const { userId, cluster } = req.params;
    const users = safeLoad(USER_DATA_PATH, {});
    const cms = safeLoad(CMS_PATH, { clusters: {} });
    const clusterData = cms.clusters?.[cluster];
    if (!clusterData) return res.status(404).json({ error: 'Cluster non trovato' });

    const all = users[userId]?.answers || {};
    const nested = all[cluster];
    if (nested) return res.json({ answers: nested });

    const qids = new Set((clusterData.questionnaire || []).map(q => q.id).filter(Boolean));
    const flat = all;
    const filtered = Object.fromEntries(Object.entries(flat || {}).filter(([k]) => qids.has(k)));
    return res.json({ answers: filtered });
  } catch (e) {
    res.status(500).json({ error: 'Errore lettura risposte' });
  }
});

// POST salva risposte per cluster (merge) — FIX: inizializzazione answers
router.post('/:userId/:cluster', (req, res) => {
  try {
    const { userId, cluster } = req.params;
    const { answers } = req.body || {};
    if (!answers || typeof answers !== 'object') {
      return res.status(400).json({ error: 'answers mancanti' });
    }

    const users = safeLoad(USER_DATA_PATH, {});
    // inizializza struttura annidata in modo sicuro
    users[userId] = users[userId] || {};
    users[userId].answers = users[userId].answers && typeof users[userId].answers === 'object'
      ? users[userId].answers
      : {};

    const byCluster = users[userId].answers;
    byCluster[cluster] = { ...(byCluster[cluster] || {}), ...answers };
    users[userId].answers = byCluster;

    saveJson(USER_DATA_PATH, users);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'Errore salvataggio risposte' });
  }
});

// Reset risposte cluster — FIX: inizializzazione answers
router.post('/:userId/reset/:cluster', (req, res) => {
  try {
    const { userId, cluster } = req.params;
    const users = safeLoad(USER_DATA_PATH, {});
    users[userId] = users[userId] || {};
    users[userId].answers = users[userId].answers && typeof users[userId].answers === 'object'
      ? users[userId].answers
      : {};
    users[userId].answers[cluster] = {};
    saveJson(USER_DATA_PATH, users);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'Errore reset cluster' });
  }
});

module.exports = router;
