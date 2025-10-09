# Questionnaire iOS App

Questa cartella contiene l'app iOS nativa (SwiftUI) che replica le funzionalità del frontend web esistente.

## Struttura
- `QuestionnaireApp.xcodeproj`: progetto Xcode dell'app.
- `QuestionnaireApp/`: codice sorgente SwiftUI, modelli, view model, networking e risorse.

## Requisiti
- Xcode 15 o successivo.
- iOS 16 come minimo target di deployment.
- Backend Node.js attivo su `http://localhost:3001` (stessa API del frontend web).

## Avvio
1. Apri `QuestionnaireApp.xcodeproj` con Xcode.
2. Assicurati che il backend sia in esecuzione (`npm start` per il frontend oppure `node backend/server.js` per il solo API server).
3. Esegui l'app su simulatore o dispositivo reale.

Il file `AppConfiguration.swift` contiene l'URL base del backend e l'ID utente di test (attualmente `user_123`).

## Download rapido del progetto iOS
Per scaricare l'intero progetto iOS in un singolo archivio ZIP, è disponibile uno script di supporto:

```bash
python scripts/export_ios_project.py
```

Il comando precedente genererà `QuestionnaireApp.zip` nella cartella corrente, contenente tutto il contenuto di `ios/QuestionnaireApp`. È possibile specificare un percorso di destinazione diverso:

```bash
python scripts/export_ios_project.py /percorso/destinazione/QuestionnaireApp.zip
```

Per esportare una cartella diversa (ad esempio una copia modificata), usare l'opzione `--source`:

```bash
python scripts/export_ios_project.py --source ios/QuestionnaireApp /tmp/mio_progetto_ios.zip
```
