const express = require('express');
const fs = require('fs');
const path = require('path');
const router = express.Router();

const CMS_PATH = path.join(__dirname, '../data/cms.json');

// GET /api/cms - restituisce il contenuto di cms.json
router.get('/', (req, res) => {
  fs.readFile(CMS_PATH, 'utf8', (err, data) => {
    if (err) return res.status(500).json({ error: 'Impossibile leggere il file CMS' });
    try {
      res.json(JSON.parse(data));
    } catch {
      res.status(500).json({ error: 'File CMS non valido' });
    }
  });
});

// POST /api/cms - sovrascrive il file cms.json
router.post('/', (req, res) => {
  try {
    const json = JSON.stringify(req.body, null, 2);
    fs.writeFile(CMS_PATH, json, 'utf8', (err) => {
      if (err) return res.status(500).json({ error: 'Impossibile salvare il file CMS' });
      res.json({ ok: true });
    });
  } catch {
    res.status(400).json({ error: 'JSON non valido' });
  }
});

module.exports = router;