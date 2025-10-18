// api.js - layer di servizio per il frontend React
// Incapsula tutte le chiamate REST al backend

const USER_ID = 'user_123';
const base = '';// proxy in package.json punta a http://localhost:3001

async function jsonFetch(url, options = {}) {
  const resp = await fetch(url, { headers: { 'Content-Type': 'application/json' }, ...options });
  if (!resp.ok) {
    let msg = `HTTP ${resp.status}`;
    try { const j = await resp.json(); msg = j.error || msg; } catch {}
    throw new Error(msg);
  }
  return resp.json();
}

// Lista progress questionari (clusters)
export async function fetchProgress() {
  return jsonFetch(`/api/progress/${USER_ID}`);
}

// Domande formato classico
export async function fetchQuestionnaire(cluster) {
  return jsonFetch(`/api/questionnaire/${cluster}`); // array
}

// Risposte formato classico
export async function fetchAnswers(cluster) {
  return jsonFetch(`/api/userAnswers/${USER_ID}/${cluster}`);
}

export async function saveAnswers(cluster, answers) {
  return jsonFetch(`/api/userAnswers/${USER_ID}/${cluster}`, {
    method: 'POST',
    body: JSON.stringify({ answers })
  });
}

export async function resetAnswers(cluster) {
  return jsonFetch(`/api/userAnswers/${USER_ID}/reset/${cluster}`, { method: 'POST' });
}

// Pagine (nuovo formato)
export async function fetchPages(cluster) {
  return jsonFetch(`/api/pages/${cluster}`); // { title, pages: [...] }
}

export async function fetchPageAnswers(cluster) {
  return jsonFetch(`/api/pageAnswers/${USER_ID}/${cluster}`); // { pageAnswers }
}

export async function fetchSinglePage(pageId) {
  return jsonFetch(`/api/pages/page/${pageId}`);
}

export async function savePageAnswers(cluster, pageId, answers) {
  return jsonFetch(`/api/pageAnswers/${USER_ID}/${cluster}/${pageId}`, {
    method: 'POST',
    body: JSON.stringify({ answers })
  });
}

export async function resetPageAnswers(cluster) {
  return jsonFetch(`/api/pageAnswers/${USER_ID}/${cluster}/reset`, { method: 'POST' });
}

// Reset totale: svuota anche eventuali questionario classico (difensivo)
export async function resetAllForCluster(cluster) {
  try { await resetAnswers(cluster); } catch (_) { /* ignore */ }
  try { await resetPageAnswers(cluster); } catch (_) { /* ignore */ }
}

// Utility progress locale per questionari classici
export function computeQuestionnaireProgress(questions, answers, completed) {
  if (completed) return 100;
  if (!Array.isArray(questions) || questions.length === 0) return 0;
  const total = questions.length;
  const answered = Object.keys(answers || {}).filter(id => questions.some(q => q.id === id)).length;
  const pct = Math.round((answered / total) * 100);
  return completed ? 100 : Math.min(pct, 99);
}

// Motore path (replica buildFullPath)
export function buildFullPath(questions, answers) {
  const map = new Map((questions || []).map(q => [q.id, q]));
  const startId = questions?.[0]?.id;
  if (!startId) return { path: [], endReached: false };
  if (!answers || Object.keys(answers).length === 0) return { path: [startId], endReached: false };
  const path = [];
  let currentId = startId;
  let endReached = false;
  const visited = new Set();
  let safety = 0;
  while (currentId && !visited.has(currentId) && safety++ < 200) {
    path.push(currentId);
    visited.add(currentId);
    const q = map.get(currentId);
    if (!q?.next) { endReached = true; break; }
    const ans = answers[currentId];
    if (ans === undefined) break;
    let nextId = null;
    if (typeof q.next === 'string') nextId = q.next; else if (typeof q.next === 'object') nextId = q.next[ans] ?? q.next.default ?? null;
    if (!nextId || !map.has(nextId)) { endReached = true; break; }
    currentId = nextId;
  }
  return { path, endReached };
}

// Motore pagine (semplificato data-driven)
export function evaluateCondition(condition, flatAnswers) {
  const userValue = flatAnswers[condition.questionId];
  if (userValue === undefined) return false;
  const userStr = String(userValue);
  const expected = String(condition.value);
  const op = condition.operatorType || condition.operator;
  if (op === '==' || op === '!=') return op === '==' ? userStr === expected : userStr !== expected;
  const uNum = Number(userStr); const eNum = Number(expected);
  if (Number.isNaN(uNum) || Number.isNaN(eNum)) return false;
  switch (op) { case '>': return uNum > eNum; case '>=': return uNum >= eNum; case '<': return uNum < eNum; case '<=': return uNum <= eNum; default: return false; }
}

export function resolveRoutingTargets(routing, pages, flatAnswers) {
  if (!routing) return [];
  const rules = [...(routing.rules || [])].sort((a,b) => (a.priority ?? 0) - (b.priority ?? 0));
  const matchedPages = rules.filter(r => evaluateCondition(r.condition, flatAnswers)).map(r => r.nextPage);
  const targets = new Set();
  matchedPages.forEach(pid => targets.add(pid));
  if (routing.defaultAction && routing.defaultAction !== 'complete') targets.add(routing.defaultAction);
  return [...targets].map(id => pages.findIndex(p => p.id === id)).filter(i => i >= 0);
}

export function computeReachablePageIndices(pages, flatAnswers) {
  if (!Array.isArray(pages) || pages.length === 0) return new Set();
  const visited = new Set();
  const queue = [0];
  while (queue.length) {
    const idx = queue.shift();
    if (idx < 0 || idx >= pages.length || visited.has(idx)) continue;
    visited.add(idx);
    const page = pages[idx];
    if (page && page.conditionalRouting) {
      const targets = resolveRoutingTargets(page.conditionalRouting, pages, flatAnswers);
      targets.forEach(t => { if (!visited.has(t)) queue.push(t); });
    } else {
      const next = idx + 1; if (next < pages.length) queue.push(next);
    }
  }
  return visited;
}

export function calculatePageProgress(pages, pageAnswers) {
  if (!Array.isArray(pages) || pages.length === 0) return 0;
  const flatAnswers = Object.values(pageAnswers || {}).reduce((acc, answersObj) => { Object.entries(answersObj || {}).forEach(([qid,v]) => { acc[qid] = v; }); return acc; }, {});
  const reachable = computeReachablePageIndices(pages, flatAnswers);
  if (reachable.size === 0) return 0;
  let totalRequired = 0; let answeredRequired = 0;
  for (const idx of reachable) {
    const page = pages[idx]; if (!page) continue;
    const reqQuestions = (page.questions || []).filter(q => q.required === true);
    if (reqQuestions.length === 0) continue;
    totalRequired += reqQuestions.length;
    const saved = pageAnswers[page.id] || {};
    answeredRequired += reqQuestions.filter(q => saved[q.id] !== undefined).length;
  }
  if (totalRequired === 0) return 0;
  const pct = Math.round((answeredRequired / totalRequired) * 100);
  return answeredRequired === totalRequired ? 100 : Math.min(pct, 99);
}

// Pulisce risposte di pagine non più raggiungibili (simile a PageFlowEngine.cleanupUnreachablePages)
export async function cleanupUnreachablePages(cluster, pages, pageAnswers) {
  const flatAnswers = Object.values(pageAnswers || {}).reduce((acc, answersObj) => { Object.entries(answersObj || {}).forEach(([qid,v]) => { acc[qid] = v; }); return acc; }, {});
  const reachable = computeReachablePageIndices(pages, flatAnswers);
  const updated = { ...pageAnswers };
  const cleared = [];
  for (const pageId of Object.keys(pageAnswers || {})) {
    const idx = pages.findIndex(p => p.id === pageId);
    if (idx >= 0 && !reachable.has(idx) && Object.keys(updated[pageId] || {}).length > 0) {
      updated[pageId] = {};
      cleared.push(pageId);
      // Persisto svuotamento backend
      await savePageAnswers(cluster, pageId, {});
    }
  }
  return { updated, cleared };
}
