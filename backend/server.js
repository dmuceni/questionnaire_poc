const express = require('express');
const app = express();
app.use(express.json()); // necessario per leggere req.body

const cmsRouter = require('./routes/cms');
const questionnaireRouter = require('./routes/questionnaire');
const userAnswersRouter = require('./routes/userAnswers');
const progressRouter = require('./routes/progress'); // <- assicurati che il file si chiami progress.js

app.use('/api/cms', cmsRouter);
app.use('/api/questionnaire', questionnaireRouter);
app.use('/api/userAnswers', userAnswersRouter);
app.use('/api/progress', progressRouter); // <- monta la route

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log('Backend avviato su porta', PORT));
