---
description: Analyse the codebase (or existing overview docs) and generate an architecture diagram as a draw.io XML file, Excalidraw JSON file, and an inline Mermaid preview — all in one pass.
---

# Architecture Diagram Generator

Analyse the current repository and produce a visual architecture diagram. Outputs:
1. A **draw.io** file (`.drawio`) — open in diagrams.net / draw.io desktop / VS Code extension
2. An **Excalidraw** file (`.excalidraw`) — open in excalidraw.com or the VS Code extension *(only when `--format excalidraw` or `--format both` is specified)*
3. A **Mermaid preview** embedded in `docs/architecture-diagram.md` — renders in GitHub, Notion, and most markdown viewers instantly

---

## Purpose

Turns a codebase (or existing `docs/codebase-overview.md` / `docs/ml-overview.md`) into an editable, shareable architecture diagram without requiring a human to manually place boxes. The generated files are intentionally left rough — the diagramming tool's auto-layout cleans up positioning in one click.

---

## Instructions

### Step 0 — Handle `--help`

If the user passes `--help` or `-h`, print the following and do nothing else:

```
/architecture-diagram — Generate an architecture diagram from the current codebase

USAGE
  /architecture-diagram [options]

DESCRIPTION
  Reads existing overview docs (docs/codebase-overview.md, docs/ml-overview.md) or
  explores the codebase directly, then generates editable architecture diagram files.

  Always produces:
    - docs/architecture.drawio       (open in diagrams.net or VS Code draw.io extension)
    - docs/architecture-diagram.md   (Mermaid preview — renders in GitHub instantly)

  Optionally produces:
    - docs/architecture.excalidraw   (with --format excalidraw or --format both)

OPTIONS
  --format drawio        Generate draw.io only (default)
  --format excalidraw    Generate Excalidraw only
  --format both          Generate draw.io + Excalidraw
  --type <diagram-type>  Diagram focus:
                           system    — full system, all components (default)
                           data-flow — emphasise data movement and transformations
                           sequence  — Mermaid sequence diagram for one flow
                           infra     — cloud infrastructure resources
  --flow <name>          Used with --type sequence: name of the E2E flow to trace
                         e.g. --flow "delivery creation"
  --output <dir>         Override output directory (default: docs/)
  --fresh                Ignore existing diagram files and regenerate from scratch
  --help, -h             Show this help and exit

EXAMPLES
  /architecture-diagram
  /architecture-diagram --format both
  /architecture-diagram --type sequence --flow "user checkout"
  /architecture-diagram --type data-flow --format excalidraw
  /architecture-diagram --type infra --fresh

TIPS
  draw.io:    After opening, press Ctrl+Shift+H (Fit Page). Use Arrange > Layout
              to auto-arrange nodes. Ctrl+Shift+F to find any element.
  Excalidraw: Select all (Ctrl+A) and click "Tidy up" in the toolbar.
  Mermaid:    Renders immediately in GitHub — no tool needed.

RELATED SKILLS
  /codebase-overview    — Generate the source doc this diagram is built from
  /ecosystem-overview   — Multi-repo diagram across a whole system
```

### Step 1 — Gather existing knowledge

Check for and read (in priority order):
1. `docs/codebase-overview.md` — best source; already has components, integrations, data flows
2. `docs/ml-overview.md` — if present, include ML pipeline components
3. `docs/service-integrations-mind-map.md` or similar integration docs
4. `CLAUDE.md` / `README.md`

If none of those exist, explore the codebase directly:
- Entry points (`cmd/`, `src/`, `app/`, `main.go`, `main.py`, `index.ts`, etc.)
- External client files (HTTP clients, gRPC stubs, SDK wrappers)
- Database/queue config (connection strings, table definitions, topic names)
- Infrastructure files (`docker-compose.yml`, `*.tf`, `serverless.yml`, `k8s/`)

### Step 2 — Build the component inventory

Extract the following into a structured list before drawing anything:

**Nodes** — every box in the diagram:
- Internal services / lambdas / workers (with their type: API, consumer, worker, cron, etc.)
- Databases / data stores (with type: DynamoDB, PostgreSQL, Redis, S3, etc.)
- Message queues / topics (Kafka, SQS, SNS, Pub/Sub, etc.)
- External services (third-party APIs, internal platform services)
- The actor / client (partner, user, mobile app, etc.)

**Edges** — every arrow in the diagram:
- Direction: A → B
- Protocol / mechanism: REST, gRPC, Kafka, SQS, DynamoDB stream, WebSocket, etc.
- Label: short description (e.g. "POST /quotes", "deliveries topic", "DynamoDB stream")

**Groups / swim lanes** — logical groupings:
- e.g. "Public API", "Lambda Functions", "Data Stores", "External Services"

### Step 3 — Assign a layout grid

Use this deterministic layout strategy so coordinates are reasonable without needing a layout engine. The user can always hit "Auto Layout" in the tool to improve it further.

**Layout zones (top → bottom):**
```
Row 0 (y=80):    Clients / Actors
Row 1 (y=220):   Public-facing API / Gateway
Row 2 (y=380):   Internal Services / Workers / Lambdas
Row 3 (y=540):   Data Stores (databases, caches)
Row 4 (y=700):   External Services / Third-party
```

**Horizontal spacing:**
- Each node: 180px wide, 60px tall (services) or 160px wide, 50px tall (data stores)
- Horizontal gap between nodes in same row: 40px
- Centre nodes within each row
- Start x at 80px for the leftmost node in each row

Assign each node an `id` (short slug, e.g. `partner-api`, `dynamo-deliveries`) and record its `(x, y)`.

### Step 4 — Generate draw.io XML

**Always generate this format.** Output to `docs/architecture.drawio`.

Use this XML template. Increment cell IDs from `2` upward (IDs `0` and `1` are reserved for the root cells).

```xml
<mxGraphModel dx="1422" dy="762" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1654" pageHeight="1169" math="0" shadow="0">
  <root>
    <mxCell id="0" />
    <mxCell id="1" parent="0" />
    <!-- NODES and EDGES go here -->
  </root>
</mxGraphModel>
```

**Node styles by type:**

| Type | style attribute |
|------|----------------|
| HTTP API / service | `rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;` |
| Lambda / worker | `rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;` |
| Database / DynamoDB | `shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.dynamodb;fillColor=#E6D0DE;strokeColor=#AE4132;` *(or use a plain cylinder: `shape=mxgraph.flowchart.database;fillColor=#f8cecc;strokeColor=#b85450;`)* |
| Kafka topic / SQS queue | `shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.sqs;fillColor=#fff2cc;strokeColor=#d6b656;` *(or plain hexagon: `shape=hexagon;fillColor=#fff2cc;strokeColor=#d6b656;`)* |
| External service | `rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;fontColor=#333333;` |
| Actor / client | `shape=mxgraph.mockup.containers.smartphone;fillColor=#f0f0f0;strokeColor=#666666;` *(or plain ellipse: `ellipse;fillColor=#f0f0f0;strokeColor=#666666;`)* |
| Swim lane group | `swimlane;startSize=30;fillColor=#f5f5f5;strokeColor=#666666;` |

**Node cell template:**
```xml
<mxCell id="NODE_ID" value="Display Name" style="STYLE" vertex="1" parent="1">
  <mxGeometry x="X" y="Y" width="W" height="H" as="geometry" />
</mxCell>
```

**Edge cell template:**
```xml
<mxCell id="EDGE_ID" value="label" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;exitX=1;exitY=0.5;exitDx=0;exitDy=0;entryX=0;entryY=0.5;entryDx=0;entryDy=0;" edge="1" source="SOURCE_NODE_ID" target="TARGET_NODE_ID" parent="1">
  <mxGeometry relative="1" as="geometry" />
</mxCell>
```

**Swim lane group template** (add nodes inside by setting `parent="GROUP_ID"`):
```xml
<mxCell id="GROUP_ID" value="Group Name" style="swimlane;startSize=30;fillColor=#f5f5f5;strokeColor=#aaaaaa;" vertex="1" parent="1">
  <mxGeometry x="X" y="Y" width="W" height="H" as="geometry" />
</mxCell>
```

### Step 5 — Generate Excalidraw JSON (only if `--format excalidraw` or `--format both`)

Output to `docs/architecture.excalidraw`.

Use the same grid positions from Step 3. Map each node to an Excalidraw element. Use this exact schema (Excalidraw v2):

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "architecture-diagram-skill",
  "elements": [],
  "appState": {
    "viewBackgroundColor": "#ffffff",
    "gridSize": 20
  },
  "files": {}
}
```

**Node element template:**
```json
{
  "id": "NODE_ID",
  "type": "rectangle",
  "x": X,
  "y": Y,
  "width": W,
  "height": H,
  "angle": 0,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "FILL_COLOR",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "groupIds": [],
  "roundness": { "type": 3 },
  "isDeleted": false,
  "boundElements": [],
  "updated": 1,
  "link": null,
  "locked": false
}
```

**Label element template** (place at node centre, y offset -5 from node y):
```json
{
  "id": "LABEL_NODE_ID",
  "type": "text",
  "x": X,
  "y": Y_CENTER,
  "width": W,
  "height": 20,
  "text": "Display Name",
  "fontSize": 14,
  "fontFamily": 1,
  "textAlign": "center",
  "verticalAlign": "middle",
  "strokeColor": "#1e1e1e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "groupIds": [],
  "isDeleted": false,
  "boundElements": [],
  "updated": 1,
  "link": null,
  "locked": false
}
```

**Arrow element template:**
```json
{
  "id": "EDGE_ID",
  "type": "arrow",
  "x": START_X,
  "y": START_Y,
  "width": DELTA_X,
  "height": DELTA_Y,
  "points": [[0, 0], [DELTA_X, DELTA_Y]],
  "angle": 0,
  "strokeColor": "#1e1e1e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 1,
  "opacity": 100,
  "groupIds": [],
  "startBinding": { "elementId": "SOURCE_NODE_ID", "focus": 0, "gap": 4 },
  "endBinding": { "elementId": "TARGET_NODE_ID", "focus": 0, "gap": 4 },
  "startArrowhead": null,
  "endArrowhead": "arrow",
  "isDeleted": false,
  "boundElements": [],
  "updated": 1,
  "link": null,
  "locked": false
}
```

**Fill colours by type:**
| Type | backgroundColor |
|------|----------------|
| HTTP API | `#a5d8ff` |
| Lambda / worker | `#b2f2bb` |
| Database | `#ffc9c9` |
| Queue / topic | `#ffec99` |
| External service | `#e9ecef` |
| Actor | `#dee2e6` |

### Step 6 — Generate Mermaid preview

Always generate this regardless of `--format`. Embed in `docs/architecture-diagram.md`.

**Layout choice:**
- Use `graph LR` (left-to-right) for services with multiple layers of components — it spreads horizontally and avoids vertical crowding.
- Use `graph TD` (top-down) only for simple linear pipelines with 5 or fewer rows.
- When in doubt, default to `graph LR`.

**Inside subgraphs** with many components, add `direction TB` so those components stack vertically within the swim lane:
```
subgraph lambdas["Lambda Functions"]
    direction TB
    ConsumerA["deliveries-consumer"]
    ConsumerB["pickups-consumer"]
    ...
end
```

**MANDATORY — Never abbreviate components.** Every Lambda, consumer, worker, data store, and queue must be its own named node. Do not write `"...N other services"` or `"workers (N)"`. If there are 18 Lambdas, show 18 nodes.

```markdown
## Architecture Diagram

> Auto-generated. For the editable source open `docs/architecture.drawio` in [diagrams.net](https://app.diagrams.net) or `docs/architecture.excalidraw` in [Excalidraw](https://excalidraw.com).
>
> **draw.io tip:** After opening, press `Ctrl+Shift+H` (Fit Page) then `Arrange > Layout` to auto-arrange nodes.

```mermaid
graph LR
    ...
```
```

Group related nodes using Mermaid subgraphs:
```
subgraph lambdas["Lambda Functions"]
    direction TB
    ...
end
```

Apply Mermaid styles per node type:
```
classDef api fill:#dae8fc,stroke:#6c8ebf
classDef worker fill:#d5e8d4,stroke:#82b366
classDef db fill:#f8cecc,stroke:#b85450
classDef queue fill:#fff2cc,stroke:#d6b656
classDef external fill:#f5f5f5,stroke:#666666
```

### Step 7 — Write output files

Write all generated files. Always write:
- `docs/architecture.drawio` (always)
- `docs/architecture-diagram.md` (always — contains Mermaid + instructions)

Only write if `--format excalidraw` or `--format both`:
- `docs/architecture.excalidraw`

Add a `<!-- Last updated: YYYY-MM-DD -->` comment as the first line in `architecture-diagram.md`.

If any of these files already exist, merge: detect new components and edges, add them, keep existing layout adjustments the user may have made (if coordinates differ significantly from the default grid, they were likely hand-tuned — preserve them).

---

## Parameters

- `--format drawio` *(default)* — generate draw.io XML only
- `--format excalidraw` — generate Excalidraw JSON only
- `--format both` — generate both draw.io and Excalidraw
- `--type <diagram-type>` — focus on a specific view (default: `system`):
  - `system` — full system with all components and external deps
  - `data-flow` — emphasise data movement and transformations
  - `sequence` — Mermaid `sequenceDiagram` for a specific E2E flow (combine with `--flow`)
  - `infra` — cloud infrastructure resources
- `--flow <flow-name>` — when `--type sequence`, focus on a named flow (e.g. `--flow "delivery creation"`)
- `--output <dir>` — override output directory (default: `docs/`)
- `--fresh` — ignore existing diagram files and regenerate from scratch

## Examples

### Example 1: Quick system overview (draw.io only)
When the user says "/architecture-diagram", read existing overview docs, build the component inventory, and generate `docs/architecture.drawio` + `docs/architecture-diagram.md`.

### Example 2: Both formats
When the user says "/architecture-diagram --format both", generate both `docs/architecture.drawio` and `docs/architecture.excalidraw`.

### Example 3: Sequence diagram for a specific flow
When the user says "/architecture-diagram --type sequence --flow 'delivery creation'", generate a Mermaid `sequenceDiagram` in `docs/architecture-diagram.md` tracing that specific E2E flow with all actors and messages.

### Example 4: Data-flow focused
When the user says "/architecture-diagram --type data-flow", emphasise how data moves through the system — highlight data stores, transformation steps, and Kafka/queue topics more prominently.

### Example 5: Infrastructure view
When the user says "/architecture-diagram --type infra", focus on cloud resources (Lambda, DynamoDB, SQS, S3, VPC, etc.) rather than logical service components.

## Notes

- **draw.io auto-layout:** After opening the `.drawio` file, use `Extras > Edit Diagram` to paste updated XML, or `Arrange > Layout` to auto-arrange nodes. `Ctrl+Shift+H` fits the page.
- **Excalidraw tidy-up:** After opening, select all (`Ctrl+A`) and use the "Tidy up" button in the toolbar to improve spacing.
- **Mermaid is always the fastest win** — if the user just needs a quick visual, the Mermaid in `architecture-diagram.md` renders immediately in GitHub without opening any tool.
- When `docs/codebase-overview.md` exists, always prefer it as the source of truth over direct codebase exploration — it's faster and already has the right level of abstraction.
- Do not include every internal function or class — diagrams should show components (services, stores, queues) and their connections, not code internals.
- Edge labels should be concise: protocol + key detail (e.g. "gRPC", "Kafka: deliveries", "DynamoDB stream", "REST POST /quotes").
- If the system has more than ~30 nodes, produce **two diagrams**: (1) a full component diagram with every node, and (2) a simplified critical-path diagram with one node per logical group. Never collapse real components into placeholder nodes — always show the full inventory in diagram 1.
- Always note at the top of `architecture-diagram.md`: "Run `/codebase-overview` to regenerate the source docs this diagram is based on."