## 🔍 DEBUG: Test del Sistema di Routing Condizionale 

Per risolvere il problema, testiamo passo per passo:

### 🧪 **Test Scenario:**

1. **Apri l'app nel simulatore**
2. **Vai alla pagina "I Tuoi Interessi"**
3. **Imposta i seguenti valori:**
   - Cinema: ⭐⭐⭐⭐⭐ (5 stelle)
   - Calcio: ⭐⭐⭐⭐ (4 stelle)  
   - Sport: ⭐⭐ (2 stelle)
4. **Premi "Continua"**

### 📊 **Output Debug Atteso:**

Con il debug aggiunto, dovresti vedere nella console:

```
🔍 DEBUG: Available answers: ["interesse_calcio", "interesse_cinema", "interesse_sport"]
🔍 DEBUG: Looking for answer with questionId: 'interesse_cinema'
🔍 DEBUG: Found rating answer for 'interesse_cinema': 5
🔍 DEBUG: Checking rule for interesse_cinema: got value 5, need >= 3
🔍 DEBUG: ✅ Condition MET for interesse_cinema: 5 >= 3 -> page_cinema

🔍 DEBUG: Looking for answer with questionId: 'interesse_calcio' 
🔍 DEBUG: Found rating answer for 'interesse_calcio': 4
🔍 DEBUG: Checking rule for interesse_calcio: got value 4, need >= 3
🔍 DEBUG: ✅ Condition MET for interesse_calcio: 4 >= 3 -> page_calcio

🔍 DEBUG: Found 2 matching pages: ["page_cinema", "page_calcio"]
🔍 DEBUG: Starting conditional sequence: page_cinema (1/2)
```

### 🚨 **Se il Debug Mostra:**

**Problema 1: Chiavi sbagliate**
```
🔍 DEBUG: Available answers: ["cinema", "calcio", "sport"] 
🔍 DEBUG: Looking for answer with questionId: 'interesse_cinema'
🔍 DEBUG: No answer found for 'interesse_cinema', returning 0
```
→ **Soluzione**: Le chiavi delle risposte non corrispondono al CMS

**Problema 2: Valori non salvati**  
```
🔍 DEBUG: Available answers: []
```
→ **Soluzione**: Le risposte non vengono salvate correttamente

**Problema 3: Conditional routing non trovato**
```
(Nessun output di debug)
```
→ **Soluzione**: La pagina non ha conditional routing configurato

### 🔧 **Prossimi Passi:**

Una volta che vedi il debug output, sapremo esattamente dove sta il problema e potrò correggerlo immediatamente.

**Testa l'app ora e dimmi cosa vedi nei log di debug!**