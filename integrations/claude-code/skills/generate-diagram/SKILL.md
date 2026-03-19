---
name: generate-diagram
description: Generate architecture diagrams as draw.io XML, Excalidraw JSON, and Mermaid preview. Use when asked to create architecture diagrams, visualise a system, diagram a specific E2E flow, or produce draw.io / Excalidraw / Mermaid files from a codebase or component inventory.
allowed-tools: Read Write Edit Bash
---

# Generate Diagram

Produce architecture diagram files from the available codebase knowledge. Always outputs a Mermaid preview; optionally outputs draw.io XML and/or Excalidraw JSON.

## When to use this skill

- Called by `/architecture-diagram` and `/codebase-overview --with-diagram`
- Called by `/ecosystem-overview` for the ecosystem-level diagram
- Use autonomously to produce a visual diagram from any codebase or component inventory

---

## Input Priority

Read inputs in this order, stopping at the first that exists:

1. **`docs/codebase-index.json`** — best source; `components[]`, `flows[]`, `architecture` field already extracted
2. **`docs/codebase-overview.md`** — already has components, integrations, data flows in prose form
3. **`docs/ml-overview.md`** — supplement if present (adds ML pipeline components)
4. **Direct exploration** — entry points, external clients, DB config, infra files

---

## Step 1 — Build the Component Inventory

Extract the following before drawing anything.

**Nodes** (every box in the diagram):
- Internal services / lambdas / workers (type: API, consumer, worker, cron)
- Databases / data stores (type: DynamoDB, PostgreSQL, Redis, S3, etc.)
- Message queues / topics (Kafka, SQS, SNS, Pub/Sub, etc.)
- External third-party services
- The actor / client (partner, user, mobile app, etc.)

**Edges** (every arrow):
- Direction: A → B
- Protocol / mechanism: REST, gRPC, Kafka, SQS, DynamoDB stream, WebSocket, etc.
- Label: short description (e.g. `POST /quotes`, `deliveries topic`, `DynamoDB stream`)

**Groups / swim lanes:**
- e.g. "Public API", "Lambda Functions", "Data Stores", "External Services"

**When reading from `codebase-index.json`:**
- Nodes ← `components[]` (use `type` and `layer` fields)
- Edges ← `components[].deps` (derive direction and mechanism from component types)
- Groups ← group components by `layer` value
- External services ← `architecture.external_services`

**MANDATORY: Never abbreviate.** Every Lambda, consumer, worker, data store, and queue must be its own named node. Do not write `"...N other services"` or `"workers (N)"`. If there are 18 Lambdas, show 18 nodes.

---

## Step 2 — Assign Layout Grid

Use this deterministic grid so coordinates are reasonable without a layout engine. Users can run "Auto Layout" in their tool to improve further.

```
Row 0 (y=80):   Clients / Actors
Row 1 (y=220):  Public-facing API / Gateway
Row 2 (y=380):  Internal Services / Workers / Lambdas
Row 3 (y=540):  Data Stores (databases, caches, queues)
Row 4 (y=700):  External Services / Third-party
```

Horizontal spacing:
- Service node: 180px wide, 60px tall
- Data store node: 160px wide, 50px tall
- Gap between nodes in the same row: 40px
- Start x at 80px for the leftmost node in each row
- Centre nodes within each row

Assign each node a short slug ID (e.g. `partner-api`, `dynamo-deliveries`) and record its `(x, y)`.

---

## Step 3 — Generate draw.io XML

Output to `docs/architecture.drawio` (or `--output` dir).

Use this root template:

```xml
<mxGraphModel dx="1422" dy="762" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1654" pageHeight="1169" math="0" shadow="0">
  <root>
    <mxCell id="0" />
    <mxCell id="1" parent="0" />
    <!-- NODES and EDGES go here, IDs start from 2 -->
  </root>
</mxGraphModel>
```

**Node styles by type:**

| Type | `style` attribute |
|------|-------------------|
| HTTP API / service | `rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;` |
| Lambda / worker | `rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;` |
| Database / DynamoDB | `shape=mxgraph.flowchart.database;fillColor=#f8cecc;strokeColor=#b85450;` |
| Kafka topic / SQS queue | `shape=hexagon;fillColor=#fff2cc;strokeColor=#d6b656;` |
| External service | `rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;fontColor=#333333;` |
| Actor / client | `ellipse;fillColor=#f0f0f0;strokeColor=#666666;` |
| Swim lane group | `swimlane;startSize=30;fillColor=#f5f5f5;strokeColor=#aaaaaa;` |

**Node cell template:**
```xml
<mxCell id="NODE_ID" value="Display Name" style="STYLE" vertex="1" parent="1">
  <mxGeometry x="X" y="Y" width="W" height="H" as="geometry" />
</mxCell>
```

**Edge cell template:**
```xml
<mxCell id="EDGE_ID" value="label" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;exitX=1;exitY=0.5;exitDx=0;exitDy=0;entryX=0;entryY=0.5;entryDx=0;entryDy=0;" edge="1" source="SOURCE_ID" target="TARGET_ID" parent="1">
  <mxGeometry relative="1" as="geometry" />
</mxCell>
```

**Swim lane group template** (child nodes use `parent="GROUP_ID"`):
```xml
<mxCell id="GROUP_ID" value="Group Name" style="swimlane;startSize=30;fillColor=#f5f5f5;strokeColor=#aaaaaa;" vertex="1" parent="1">
  <mxGeometry x="X" y="Y" width="W" height="H" as="geometry" />
</mxCell>
```

---

## Step 4 — Generate Excalidraw JSON (only if `--format excalidraw` or `--format both`)

Output to `docs/architecture.excalidraw`. Use the same grid positions from Step 2.

Root structure (Excalidraw v2):
```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "generate-diagram-skill",
  "elements": [],
  "appState": { "viewBackgroundColor": "#ffffff", "gridSize": 20 },
  "files": {}
}
```

**Node element:**
```json
{
  "id": "NODE_ID", "type": "rectangle",
  "x": X, "y": Y, "width": W, "height": H,
  "angle": 0, "strokeColor": "#1e1e1e", "backgroundColor": "FILL_COLOR",
  "fillStyle": "solid", "strokeWidth": 2, "strokeStyle": "solid",
  "roughness": 1, "opacity": 100, "groupIds": [],
  "roundness": { "type": 3 }, "isDeleted": false,
  "boundElements": [], "updated": 1, "link": null, "locked": false
}
```

**Label element** (centre of node, y offset +H/2 - 10):
```json
{
  "id": "LABEL_NODE_ID", "type": "text",
  "x": X, "y": Y_CENTER, "width": W, "height": 20,
  "text": "Display Name", "fontSize": 14, "fontFamily": 1,
  "textAlign": "center", "verticalAlign": "middle",
  "strokeColor": "#1e1e1e", "backgroundColor": "transparent",
  "fillStyle": "solid", "roughness": 1, "opacity": 100,
  "groupIds": [], "isDeleted": false, "boundElements": [],
  "updated": 1, "link": null, "locked": false
}
```

**Arrow element:**
```json
{
  "id": "EDGE_ID", "type": "arrow",
  "x": START_X, "y": START_Y, "width": DELTA_X, "height": DELTA_Y,
  "points": [[0, 0], [DELTA_X, DELTA_Y]],
  "angle": 0, "strokeColor": "#1e1e1e", "backgroundColor": "transparent",
  "fillStyle": "solid", "strokeWidth": 2, "strokeStyle": "solid",
  "roughness": 1, "opacity": 100, "groupIds": [],
  "startBinding": { "elementId": "SOURCE_ID", "focus": 0, "gap": 4 },
  "endBinding": { "elementId": "TARGET_ID", "focus": 0, "gap": 4 },
  "startArrowhead": null, "endArrowhead": "arrow",
  "isDeleted": false, "boundElements": [], "updated": 1, "link": null, "locked": false
}
```

**Fill colours by type:**

| Type | `backgroundColor` |
|------|-------------------|
| HTTP API | `#a5d8ff` |
| Lambda / worker | `#b2f2bb` |
| Database | `#ffc9c9` |
| Queue / topic | `#ffec99` |
| External service | `#e9ecef` |
| Actor | `#dee2e6` |

---

## Step 5 — Generate Mermaid Preview

Always generate this regardless of format flags. Embed in `docs/architecture-diagram.md`.

**Layout choice:**
- Use `graph LR` (left-to-right) for systems with multiple component layers — it spreads horizontally.
- Use `graph TD` only for simple linear pipelines with ≤5 rows.
- Default: `graph LR`.

**Inside subgraphs** with many components, add `direction TB`:
```
subgraph lambdas["Lambda Functions"]
    direction TB
    ConsumerA["deliveries-consumer"]
    ConsumerB["pickups-consumer"]
end
```

**MANDATORY: Never abbreviate.** Every Lambda, consumer, worker, data store, and queue must be its own named node.

Apply classDef styles:
```
classDef api fill:#dae8fc,stroke:#6c8ebf
classDef worker fill:#d5e8d4,stroke:#82b366
classDef db fill:#f8cecc,stroke:#b85450
classDef queue fill:#fff2cc,stroke:#d6b656
classDef external fill:#f5f5f5,stroke:#666666
```

The `docs/architecture-diagram.md` file format:

```markdown
<!-- Last updated: YYYY-MM-DD -->

# Architecture Diagram

> Auto-generated. Open `docs/architecture.drawio` in [diagrams.net](https://app.diagrams.net).
> **draw.io tip:** Press `Ctrl+Shift+H` (Fit Page) then `Arrange > Layout` to auto-arrange nodes.
> Run `/codebase-overview` to regenerate the source docs this diagram is built from.

```mermaid
graph LR
    ...
```
```

---

## Step 6 — Merge with existing files

If any output file already exists:
- Read the existing file first
- Detect new components/edges in the updated inventory and add them
- **Preserve hand-tuned coordinates**: if existing node coordinates differ significantly from the default grid (>50px), they were likely manually adjusted — keep them
- Update the `<!-- Last updated: YYYY-MM-DD -->` line

If `--fresh` was passed: overwrite without merging.

---

## Parameters

- `--format drawio` *(default)*: generate draw.io XML only
- `--format excalidraw`: generate Excalidraw JSON only
- `--format both`: generate both draw.io and Excalidraw
- `--type system` *(default)*: full system, all components
- `--type data-flow`: emphasise data movement and transformations
- `--type sequence`: Mermaid `sequenceDiagram` for one specific flow (use with `--flow`)
- `--type infra`: cloud infrastructure resources (Lambda, DynamoDB, SQS, VPC, etc.)
- `--flow <name>`: name of the E2E flow to trace when `--type sequence`
- `--output <dir>`: override output directory (default: `docs/`)
- `--fresh`: ignore existing diagram files and regenerate from scratch

---

## Notes

- **Always generate the Mermaid preview** regardless of `--format`. It's the fastest win for GitHub rendering.
- **draw.io tip for users:** After opening, press `Ctrl+Shift+H` (Fit Page) then `Arrange > Layout`.
- **Excalidraw tip for users:** Select all (`Ctrl+A`) and click "Tidy up" in the toolbar.
- Diagrams should show components and connections — not internal functions or classes.
- Edge labels: concise protocol + key detail (`"gRPC"`, `"Kafka: deliveries"`, `"REST POST /quotes"`).
- If the system has >30 nodes: produce two diagrams — (1) full component diagram, (2) simplified critical-path view with one node per logical group.
- For sequence diagrams (`--type sequence`): use `sequenceDiagram` syntax with `participant` declarations and `->>`/`-->>`/`->>+` notation for sync/async/activate.
