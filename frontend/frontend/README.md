## Frontend Questionario React

Implementazione web del flusso questionario con due modalità:

1. Modalità "classica" (routing per domanda) — rotta: `/questionario/:cluster`
2. Modalità a "pagine" data‑driven — rotta: `/questionario-pagine/:cluster`

Il backend (proxy su `localhost:3001`) espone API per:
- Domande classiche: `GET /api/questionnaire/:cluster`
- Risposte classiche: `GET/POST /api/userAnswers/:userId/:cluster`
- Pagine: `GET /api/pages/:cluster`
- Risposte pagine: `GET/POST /api/pageAnswers/:userId/:cluster(/:pageId)`
- Progress globale: `GET /api/progress/:userId`

### Architettura principale

```
src/
	api.js                // layer di servizio REST
	App.js                // definizione rotte
	components/
		QuestionnaireLoader // flusso classico domanda-per-domanda
		QuestionnairePageFlow.jsx // nuovo flusso a pagine
		PageView.jsx        // rendering singola pagina con n domande
		ProgressBar.jsx     // barra avanzamento riusabile
		Question.js         // rendering di vari tipi di domanda
	pages/
		QuestionnaireList.js // elenco cluster + percentuali
```

Motori logici riutilizzati da backend / iOS sono stati tradotti in JS dentro `api.js` (funzioni `buildFullPath`, `calculatePageProgress`, ecc.).

### Avvio

1. Avvia backend (cartella `backend`):
2. Avvia frontend:

```
npm install
npm start
```

Apri `http://localhost:3000`.

### Aggiungere un nuovo tipo domanda
Estendere `Question.js` aggiungendo un nuovo branch condizionale e relativo markup / stile.

### Passare dalla modalità classica a pagine
Per un cluster esistente visita `/questionario-pagine/<cluster>`. Se nel CMS il cluster contiene già `pages`, verranno usate direttamente; altrimenti il backend farà un wrapping automatico delle domande in pagine (chunk di 3 domande).

### Calcolo progresso
Modalità classica: percentuale = domande risposte / totale, con 99% prima di completare l'ultima.
Modalità a pagine: considera solo domande `required` nelle pagine raggiungibili (routing condizionale), analogamente alla logica Swift e backend.

### Esempio di cluster con routing condizionale
`contenuti_televisivi` e `mezzi_trasporto` usano rating iniziali (>=3) per attivare pagine di approfondimento. Il motore:
- Calcola le pagine raggiungibili dal nodo iniziale (BFS condizionale).
- Mostra sempre la prima pagina raggiungibile non completata.
- Considera completato il questionario solo quando tutte le pagine raggiungibili con domande required sono risposte.

### Nuovo cluster `mezzi_trasporto`
Struttura:
- Pagina iniziale `page_mezzi_intro` con tre rating (auto, moto/scooter, mezzi pubblici).
- Pagine condizionali: `page_auto`, `page_moto`, `page_pubblici` se il rating corrispondente >=3.
- Pagina finale sempre raggiungibile `page_mezzi_finale`.

### Pulizia codice effettuata
- Rimossi file di backup e componenti duplicati non usati (`QuestionnaireLoader.js.backup`, vecchia lista `questionaires.js`, `logo.svg`).
- Consolidato flusso pagine con stack di navigazione per il tasto Indietro e reset risposte pagina.
- Aggiornata logica di routing per evitare completamento anticipato.
- Eliminato boilerplate Create React App (`App.test.js`, `setupTests.js`, `reportWebVitals.js`) per ridurre rumore.

### Reset risposte
Classico: POST `/api/userAnswers/:userId/reset/:cluster` (bottone "Ricomincia").
Pagine: POST `/api/pageAnswers/:userId/:cluster/reset` (aggiungere UI se necessario).

### TODO futuri
- Pulizia risposte di pagine non più raggiungibili quando cambiano condizioni (mirror logica Swift `cleanupUnreachablePages`).
- Gestione bozza locale offline.
- Validazioni avanzate e messaggi inline.
- Animazioni transizione pagina.
- Test unitari su motori (buildFullPath, calculatePageProgress).

---
Questo README sostituisce quello generato automaticamente da Create React App per fornire documentazione ad-hoc del progetto.
