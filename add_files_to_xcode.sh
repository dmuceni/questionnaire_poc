#!/bin/bash

# Script per aggiungere i nuovi file al progetto Xcode
echo "Aggiungendo i nuovi file al progetto Xcode..."

# Copia i file nella struttura corretta se non esistono già
echo "Verificando che i file esistano..."

FILES=(
    "ios/QuestionnaireApp/QuestionnaireApp/Models/PageModels.swift"
    "ios/QuestionnaireApp/QuestionnaireApp/Views/QuestionnairePageView.swift"
    "ios/QuestionnaireApp/QuestionnaireApp/Views/QuestionnairePageFlowView.swift"
    "ios/QuestionnaireApp/QuestionnaireApp/ViewModels/QuestionnairePageFlowViewModel.swift"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file esiste"
    else
        echo "❌ $file non trovato"
    fi
done

echo ""
echo "Per completare l'integrazione:"
echo "1. Apri Xcode"
echo "2. Aggiungi manualmente i file al progetto"
echo "3. Sostituisci il TODO in QuestionnaireAppApp.swift con QuestionnairePageFlowView"