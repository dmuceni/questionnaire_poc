#!/bin/bash

echo "🔍 Testing CMS-driven conditional routing system..."

echo ""
echo "1️⃣ Fetching questionnaire data..."
curl -s http://127.0.0.1:3001/api/questionnaire | jq '.pages[] | select(.id == "page_interessi") | .conditionalRouting'

echo ""
echo "2️⃣ Testing rating values that should trigger sport route (rating ≥ 3)..."
curl -s -X POST http://127.0.0.1:3001/api/questionnaire/save-answers \
  -H "Content-Type: application/json" \
  -d '{
    "cluster": "test",
    "pageId": "page_interessi", 
    "answers": {
      "sport": {"type": "rating", "value": 4}
    }
  }'

echo ""
echo "3️⃣ Testing rating values that should trigger cinema route (rating ≥ 3)..."
curl -s -X POST http://127.0.0.1:3001/api/questionnaire/save-answers \
  -H "Content-Type: application/json" \
  -d '{
    "cluster": "test",
    "pageId": "page_interessi", 
    "answers": {
      "cinema": {"type": "rating", "value": 5}
    }
  }'

echo ""
echo "4️⃣ Testing values that should use default action (ratings < 3)..."
curl -s -X POST http://127.0.0.1:3001/api/questionnaire/save-answers \
  -H "Content-Type: application/json" \
  -d '{
    "cluster": "test",
    "pageId": "page_interessi", 
    "answers": {
      "sport": {"type": "rating", "value": 2},
      "cinema": {"type": "rating", "value": 1}
    }
  }'

echo ""
echo "✅ Test completed! The routing logic should now work based on CMS configuration."