
const path = require('path');
const express = require('express');
const app = express();
app.use(express.json()); // necessario per leggere req.body

const cmsRouter = require('./routes/cms');
const questionnaireRouter = require('./routes/questionnaire');
const userAnswersRouter = require('./routes/userAnswers');
const progressRouter = require('./routes/progress');
const pagesRouter = require('./routes/pages');
const pageAnswersRouter = require('./routes/pageAnswers');

app.use('/api/cms', cmsRouter);
app.use('/api/questionnaire', questionnaireRouter);
app.use('/api/userAnswers', userAnswersRouter);
app.use('/api/progress', progressRouter);
app.use('/api/pages', pagesRouter);
app.use('/api/pageAnswers', pageAnswersRouter);

// Serve static React build
app.use(express.static(path.join(__dirname, '../frontend/frontend/build')));

// Catch-all per SPA React
app.get('*', (req, res) => {
	res.sendFile(path.join(__dirname, '../frontend/frontend/build', 'index.html'));
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, '0.0.0.0', () => console.log('Backend avviato su porta', PORT, 'su tutte le interfacce'));
