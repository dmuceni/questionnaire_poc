const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

const CMS_PATH = path.join(__dirname, '../data/cms.json');
const USER_DATA_PATH = path.join(__dirname, '../data/userData.json');

function safeLoad(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch { return fallback; }
}

// percentuale basata sul percorso effettivo
function computeFlowPercent(questions, answers) {
  const qs = (questions || []).filter(q => q && q.id);
  if (qs.length === 0) return 0;
  const map = new Map(qs.map(q => [q.id, q]));
  const startId = qs[0].id;

  const visited = new Set();
  const path = [];
  let currentId = startId;
  let endReached = false;
  let safety = 0;

  while (currentId && !visited.has(currentId) && safety++ < 200) {
    path.push(currentId);
    visited.add(currentId);
    const q = map.get(currentId);
    const ans = answers[currentId];
    if (!q || !q.next) { endReached = true; break; }
    if (ans === undefined) break;

    let nextId = null;
    if (typeof q.next === 'string') nextId = q.next;
    else if (typeof q.next === 'object') nextId = q.next[ans] ?? q.next.default ?? null;

    if (!nextId || !map.has(nextId)) { endReached = true; break; }
    currentId = nextId;
  }

  const answeredOnPath = path.filter(id => answers[id] !== undefined).length;
  if (endReached && answeredOnPath === path.length) return 100;
  const denom = Math.max(path.length, 1);
  return Math.round((answeredOnPath / denom) * 100);
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
      // retrocompatibilità: se non annidato, filtra dal flat
      const qids = new Set(questions.filter(q => q && q.id).map(q => q.id));
      const flat = (typeof answersByCluster[clusterKey] === 'object') ? null : answersByCluster;
      const clusterAnswers = answersByCluster[clusterKey] || (flat
        ? Object.fromEntries(Object.entries(flat).filter(([k]) => qids.has(k)))
        : {});
      return {
        cluster: clusterKey,
        title: data.title || clusterKey,
        percent: computeFlowPercent(questions, clusterAnswers)
      };
    });

    res.json(result);
  } catch {
    res.json([]); // mai errore: torna lista vuota
  }
});

module.exports = router;