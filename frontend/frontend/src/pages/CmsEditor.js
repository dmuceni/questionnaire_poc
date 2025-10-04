import React, { useState, useEffect, useCallback } from "react";
import ReactFlow, { MiniMap, Controls, applyNodeChanges, BaseEdge, EdgeLabelRenderer } from "reactflow";
import "reactflow/dist/style.css";
import dagre from "dagre";

// Edge personalizzato con label
function LabeledEdge({ id, sourceX, sourceY, targetX, targetY, label }) {
  return (
    <>
      <BaseEdge id={id} sourceX={sourceX} sourceY={sourceY} targetX={targetX} targetY={targetY} />
      {label && (
        <EdgeLabelRenderer>
          <div style={{
            position: 'absolute',
            transform: `translate(-50%, -50%) translate(${(sourceX + targetX) / 2}px, ${(sourceY + targetY) / 2}px)`,
            background: '#fff',
            padding: '4px 12px',
            borderRadius: 6,
            border: '1px solid #0057B8',
            color: '#0057B8',
            fontWeight: 'bold',
            fontSize: 14,
            pointerEvents: 'all'
          }}>
            {label}
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  );
}

const edgeTypes = {
  labeled: LabeledEdge
};

const CMS_PATH = "/api/cms";

const nodeWidth = 280;
const nodeHeight = 80;

function getLayoutedElements(nodes, edges, direction = "TB") {
  const dagreGraph = new dagre.graphlib.Graph();
  dagreGraph.setDefaultEdgeLabel(() => ({}));
  dagreGraph.setGraph({ rankdir: direction });

  nodes.forEach((node) => {
    dagreGraph.setNode(node.id, { width: nodeWidth, height: nodeHeight });
  });

  edges.forEach((edge) => {
    dagreGraph.setEdge(edge.source, edge.target);
  });

  dagre.layout(dagreGraph);

  return nodes.map((node) => {
    const nodeWithPosition = dagreGraph.node(node.id);
    node.position = {
      x: nodeWithPosition.x - nodeWidth / 2,
      y: nodeWithPosition.y - nodeHeight / 2,
    };
    return node;
  });
}

const CmsEditor = () => {
  const [cms, setCms] = useState(null);
  const [jsonText, setJsonText] = useState("");
  const [error, setError] = useState("");
  const [nodes, setNodes] = useState([]);
  const [edges, setEdges] = useState([]);

  useEffect(() => {
    fetch(CMS_PATH)
      .then(res => res.json())
      .then(data => {
        setCms(data);
        setJsonText(JSON.stringify(data, null, 2));
        buildGraph(data);
      });
  }, []);

  const buildGraph = (cmsData) => {
    if (!cmsData?.clusters) return;
    const cluster = Object.values(cmsData.clusters)[0];
    const questions = cluster.questionnaire;
    // Filtra solo domande con id valido
    const nodeArr = questions
      .filter(q => q.id)
      .map((q, idx) => ({
        id: q.id,
        data: { label: q.text || q.id },
        position: { x: 0, y: 0 },
        draggable: true
      }));
    let edgeArr = [];
    questions.forEach(q => {
      if (q.id && q.next) {
        if (typeof q.next === "string") {
          // Edge solo se il target esiste
          if (questions.find(qq => qq.id === q.next)) {
            edgeArr.push({
              id: `${q.id}->${q.next}`,
              source: q.id,
              target: q.next,
              type: "labeled",
              label: ""
            });
          }
        } else if (typeof q.next === "object") {
          Object.entries(q.next).forEach(([answer, targetId]) => {
            if (questions.find(qq => qq.id === targetId)) {
              edgeArr.push({
                id: `${q.id}->${targetId}-${answer}`,
                source: q.id,
                target: targetId,
                type: "labeled",
                label: answer
              });
            }
          });
        }
      }
    });
    const layoutedNodes = getLayoutedElements(nodeArr, edgeArr, "TB");
    setNodes(layoutedNodes);
    setEdges(edgeArr);
  };

  const handleJsonChange = (e) => {
    setJsonText(e.target.value);
    setError("");
    try {
      const parsed = JSON.parse(e.target.value);
      setCms(parsed);
      buildGraph(parsed);
    } catch (err) {
      setError("JSON non valido");
    }
  };

  const handleSave = () => {
    try {
      const parsed = JSON.parse(jsonText);
      fetch(CMS_PATH, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(parsed)
      }).then(() => alert("Salvato!"));
    } catch {
      setError("JSON non valido");
    }
  };

  const onNodesChange = (changes) => {
    setNodes(nds => applyNodeChanges(changes, nds));
  };

  // Funzione per aggiornare una domanda
  const updateQuestion = (idx, field, value) => {
    const newCms = { ...cms };
    newCms.clusters = { ...newCms.clusters };
    const clusterKey = Object.keys(newCms.clusters)[0];
    const questions = [...newCms.clusters[clusterKey].questionnaire];
    questions[idx] = { ...questions[idx], [field]: value };
    newCms.clusters[clusterKey].questionnaire = questions;
    setCms(newCms);
    setJsonText(JSON.stringify(newCms, null, 2));
    buildGraph(newCms);
  };

  // Funzione per aggiornare le opzioni di una domanda
  const updateOption = (qIdx, optIdx, field, value) => {
    const newCms = { ...cms };
    const clusterKey = Object.keys(newCms.clusters)[0];
    const questions = [...newCms.clusters[clusterKey].questionnaire];
    const options = [...(questions[qIdx].options || [])];
    options[optIdx] = { ...options[optIdx], [field]: value };
    questions[qIdx].options = options;
    newCms.clusters[clusterKey].questionnaire = questions;
    setCms(newCms);
    setJsonText(JSON.stringify(newCms, null, 2));
    buildGraph(newCms);
  };

  // Funzione per aggiungere una nuova domanda
  const addQuestion = () => {
    const newCms = { ...cms };
    const clusterKey = Object.keys(newCms.clusters)[0];
    const questions = [...newCms.clusters[clusterKey].questionnaire];
    questions.push({
      id: `q${questions.length + 1}`,
      text: "",
      type: "card",
      options: []
    });
    newCms.clusters[clusterKey].questionnaire = questions;
    setCms(newCms);
    setJsonText(JSON.stringify(newCms, null, 2));
    buildGraph(newCms);
  };

  // Funzione per aggiungere una nuova opzione
  const addOption = (qIdx) => {
    const newCms = { ...cms };
    const clusterKey = Object.keys(newCms.clusters)[0];
    const questions = [...newCms.clusters[clusterKey].questionnaire];
    const options = [...(questions[qIdx].options || [])];
    options.push({ id: `opt${options.length + 1}`, label: "" });
    questions[qIdx].options = options;
    newCms.clusters[clusterKey].questionnaire = questions;
    setCms(newCms);
    setJsonText(JSON.stringify(newCms, null, 2));
    buildGraph(newCms);
  };

  return (
    <div style={{ maxWidth: 1600, margin: "0 auto", padding: 24 }}>
      <h1>Editor CMS & Grafo Questionario</h1>
      <div style={{ display: "flex", gap: 32, flexWrap: "wrap" }}>
        <div style={{ flex: 1, minWidth: 320 }}>
          <h2>Domande</h2>
          {cms && cms.clusters && (
            <>
              {Object.values(cms.clusters)[0].questionnaire.map((q, qIdx) => (
                <div key={q.id || qIdx} style={{ border: "1px solid #ccc", borderRadius: 8, marginBottom: 16, padding: 12 }}>
                  <label>ID: <input value={q.id} onChange={e => updateQuestion(qIdx, "id", e.target.value)} style={{ width: 120 }} /></label>
                  <br />
                  <label>Testo: <input value={q.text} onChange={e => updateQuestion(qIdx, "text", e.target.value)} style={{ width: "90%" }} /></label>
                  <br />
                  <label>Tipo:
                    <select value={q.type} onChange={e => updateQuestion(qIdx, "type", e.target.value)}>
                      <option value="card">Card</option>
                      <option value="rating">Rating</option>
                      <option value="open">Open</option>
                    </select>
                  </label>
                  <br />
                  {q.options && (
                    <div>
                      <b>Opzioni:</b>
                      {q.options.map((opt, optIdx) => (
                        <div key={opt.id || optIdx} style={{ marginLeft: 16 }}>
                          <label>ID: <input value={opt.id} onChange={e => updateOption(qIdx, optIdx, "id", e.target.value)} style={{ width: 80 }} /></label>
                          <label> Label: <input value={opt.label} onChange={e => updateOption(qIdx, optIdx, "label", e.target.value)} style={{ width: 120 }} /></label>
                        </div>
                      ))}
                      <button onClick={() => addOption(qIdx)} style={{ marginTop: 8 }}>Aggiungi opzione</button>
                    </div>
                  )}
                  <br />
                  <label>Next: <input value={typeof q.next === "string" ? q.next : JSON.stringify(q.next || {})}
                    onChange={e => updateQuestion(qIdx, "next", (() => {
                      try {
                        return JSON.parse(e.target.value);
                      } catch {
                        return e.target.value;
                      }
                    })())}
                    style={{ width: "90%" }} /></label>
                </div>
              ))}
              <button onClick={addQuestion} style={{ marginTop: 12 }}>Aggiungi domanda</button>
            </>
          )}
          <button
            onClick={handleSave}
            style={{ marginTop: 16, padding: "10px 32px", borderRadius: 8, background: "#0057B8", color: "#fff", border: "none", fontWeight: "bold", fontSize: 16 }}
          >
            Salva
          </button>
        </div>
        <div style={{
          flex: 2,
          minWidth: 800,
          height: 1200,
          background: "#fafbfc",
          borderRadius: 12,
          border: "1px solid #eee",
          padding: 12
        }}>
          <h2>Grafo delle domande</h2>
          <ReactFlow
            nodes={nodes}
            edges={edges}
            fitView
            edgeTypes={edgeTypes}
            onNodesChange={onNodesChange}
          >
            <MiniMap />
            <Controls />
          </ReactFlow>
        </div>
      </div>
    </div>
  );
};

export default CmsEditor;