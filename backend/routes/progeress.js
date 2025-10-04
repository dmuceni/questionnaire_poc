const express = require('express');
const fs = require('fs');
const path = require('path');
const router = express.Router();

const CMS_PATH = path.join(__dirname, '../data/cms.json');
const USER_DATA_PATH = path.join(__dirname, '../data/userData.json');

function loadJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

router.get('/:userId', (req, res) => {
  try {
    const userId = req.params.userId;
    const cms = loadJson(CMS_PATH);
    const users = loadJson(USER_DATA_PATH);
    const answers = users[userId]?.answers || {};
    const clusters = cms.clusters || {};

    const result = Object.entries(clusters).map(([clusterKey, data]) => {
      const questions = data.questionnaire || [];
      const total = questions.length;
      const answered = questions.filter(q => answers[q.id] !== undefined).length;
      const percent = total === 0 ? 0 : Math.round((answered / total) * 100);
      return {
        cluster: clusterKey,
        title: data.title || clusterKey,
        totalQuestions: total,
        answered,
        percent
      };
    });

    res.json(result);
  } catch (e) {
    res.status(500).json({ error: 'Errore calcolo progressi' });
  }
});

module.exports = router;