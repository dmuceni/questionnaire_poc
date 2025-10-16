const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');

// Carica i dati delle pagine
const loadPagesData = () => {
  try {
    const dataPath = path.join(__dirname, '../data/cms.json');
    const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
    return data;
  } catch (error) {
    console.error('Errore nel caricamento dei dati delle pagine:', error);
    return null;
  }
};

// GET /api/pages/:cluster - Ottieni tutte le pagine di un questionario
router.get('/:cluster', (req, res) => {
  const { cluster } = req.params;
  const data = loadPagesData();
  
  if (!data || !data.clusters || !data.clusters[cluster]) {
    return res.status(404).json({ error: 'Cluster non trovato' });
  }

  const clusterData = data.clusters[cluster];
  
  // Se il cluster ha già il formato con pagine, restituiscilo direttamente
  if (clusterData.pages) {
    res.json({
      title: clusterData.title,
      pages: clusterData.pages
    });
  } else {
    // Altrimenti, converti il formato vecchio (questionnaire) al nuovo formato (pages)
    const convertedPages = convertQuestionnaireToPages(clusterData.questionnaire);
    res.json({
      title: clusterData.title,
      pages: convertedPages
    });
  }
});

// GET /api/pages/page/:pageId - Ottieni una singola pagina per ID
router.get('/page/:pageId', (req, res) => {
  const { pageId } = req.params;
  const data = loadPagesData();
  
  if (!data || !data.clusters) {
    return res.status(404).json({ error: 'Dati non trovati' });
  }

  // Cerca la pagina in tutti i cluster
  for (const clusterName in data.clusters) {
    const cluster = data.clusters[clusterName];
    if (cluster.pages) {
      const page = cluster.pages.find(p => p.id === pageId);
      if (page) {
        return res.json(page);
      }
    }
  }
  
  return res.status(404).json({ error: 'Pagina non trovata' });
});

// Funzione per convertire il formato vecchio al nuovo
const convertQuestionnaireToPages = (questions) => {
  if (!questions || questions.length === 0) return [];
  
  // Raggruppiamo le domande in pagine logiche (3-4 domande per pagina)
  const questionsPerPage = 3;
  const pages = [];
  
  for (let i = 0; i < questions.length; i += questionsPerPage) {
    const pageQuestions = questions.slice(i, i + questionsPerPage);
    const pageNumber = Math.floor(i / questionsPerPage) + 1;
    const isLastPage = i + questionsPerPage >= questions.length;
    
    // Determina il titolo della pagina basato sul contenuto
    const pageTitle = getPageTitle(pageQuestions, pageNumber);
    
    pages.push({
      id: `page_${pageNumber}`,
      title: pageTitle,
      description: isLastPage ? 'Completa le ultime domande per finire' : 'Completa le domande in questa pagina',
      questions: pageQuestions.map(q => ({
        id: q.id,
        text: q.text,
        type: q.type,
        required: true,
        scale: q.scale,
        options: q.options,
        showIf: null
      })),
      showContinue: true,
      isLast: isLastPage,
      nextPage: isLastPage ? null : `page_${pageNumber + 1}`
    });
  }
  
  return pages;
};

// Funzione per determinare il titolo della pagina basato sul contenuto
const getPageTitle = (questions, pageNumber) => {
  if (pageNumber === 1) return 'Informazioni di Base';
  
  // Analizza le domande per determinare un titolo appropriato
  const questionTexts = questions.map(q => q.text.toLowerCase());
  
  if (questionTexts.some(text => text.includes('assicurazione') || text.includes('assicurare'))) {
    return 'Informazioni Assicurative';
  }
  
  if (questionTexts.some(text => text.includes('dispositivi') || text.includes('device') || text.includes('smartphone'))) {
    return 'I Tuoi Dispositivi';
  }
  
  if (questionTexts.some(text => text.includes('danni') || text.includes('preoccup') || text.includes('copertura'))) {
    return 'Protezione e Sicurezza';
  }
  
  if (questionTexts.some(text => text.includes('soddisf') || text.includes('grazie') || text.includes('fornitor'))) {
    return 'Valutazione Finale';
  }
  
  return `Sezione ${pageNumber}`;
};

module.exports = router;