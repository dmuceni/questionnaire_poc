const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

const CMS_PATH = path.join(__dirname, '../data/cms.json');

function safeLoad(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); }
  catch { return fallback; }
}

router.get('/:cluster', (req, res) => {
  const { cluster } = req.params;
  const cms = safeLoad(CMS_PATH, { clusters: {} });
  const data = cms.clusters?.[cluster];
  if (!data) return res.json([]); // cluster non trovato => array vuoto
  const qs = (data.questionnaire || []).filter(q => q && q.id && q.text);
  return res.json(qs);
});

module.exports = router;
