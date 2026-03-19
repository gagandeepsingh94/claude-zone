# Skill: Generate Diagram

Produce architecture diagram files from the available codebase knowledge. Always outputs a Mermaid preview; optionally outputs draw.io XML and/or Excalidraw JSON.

## When to use this skill

- Called by `architecture-diagram` and `codebase-overview --with-diagram`
- Called by `ecosystem-overview` for the ecosystem-level diagram
- Use autonomously to produce a visual diagram from any codebase or component inventory

---

## Input Priority

Read inputs in this order, stopping at the first that exists:

1. **`docs/codebase-index.json`** — best source; `components[]`, `flows[]`, `architecture` field already extracted
2. **`docs/codebase-overview.md`** — components, integrations, data flows in prose form
3. **`docs/ml-overview.md`** — supplement if present (adds ML pipeline components)
4. **Direct exploration** — entry points, external clients, DB config, infra files

---

## Step 1 — Build the Component Inventory

**Nodes** (every box in the diagram):
- Internal services / lambdas / workers
- Databases / data stores
- Message queues / topics
- External third-party services
- The actor / client

**Edges** (every arrow):
- Direction: A → B
- Protocol / mechanism: REST, gRPC, Kafka, SQS, DynamoDB stream, etc.
- Label: short description

**MANDATORY: Never abbreviate.** Every Lambda, consumer, worker, data store, and queue must be its own named node.

---

## Step 2 — Assign Layout Grid

```
Row 0 (y=80):   Clients / Actors
Row 1 (y=220):  Public-facing API / Gateway
Row 2 (y=380):  Internal Services / Workers / Lambdas
Row 3 (y=540):  Data Stores (databases, caches, queues)
Row 4 (y=700):  External Services / Third-party
```

Horizontal spacing: 180px wide, 60px tall per service node. 40px gap. Start x at 80px.

---

## Step 3 — Generate draw.io XML

Output to `docs/architecture.drawio`.

**Node styles by type:**

| Type | `style` attribute |
|------|-------------------|
| HTTP API / service | `rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;` |
| Lambda / worker | `rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;` |
| Database / DynamoDB | `shape=mxgraph.flowchart.database;fillColor=#f8cecc;strokeColor=#b85450;` |
| Kafka topic / SQS queue | `shape=hexagon;fillColor=#fff2cc;strokeColor=#d6b656;` |
| External service | `rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;` |
| Actor / client | `ellipse;fillColor=#f0f0f0;strokeColor=#666666;` |

---

## Step 4 — Generate Excalidraw JSON (only if `--format excalidraw` or `--format both`)

Output to `docs/architecture.excalidraw`. Use Excalidraw v2 format.

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

- Use `graph LR` for systems with multiple component layers.
- Use `graph TD` only for simple linear pipelines with ≤5 rows.
- **Never abbreviate.** Every component must be its own named node.

Apply classDef styles:
```
classDef api fill:#dae8fc,stroke:#6c8ebf
classDef worker fill:#d5e8d4,stroke:#82b366
classDef db fill:#f8cecc,stroke:#b85450
classDef queue fill:#fff2cc,stroke:#d6b656
classDef external fill:#f5f5f5,stroke:#666666
```

---

## Step 6 — Merge with existing files

If any output file already exists:
- Detect new components/edges and add them
- **Preserve hand-tuned coordinates** (if existing coordinates differ >50px from default grid)
- Update the `<!-- Last updated: YYYY-MM-DD -->` line

If `--fresh` was passed: overwrite without merging.

---

## Parameters

- `--format drawio` *(default)*: draw.io XML only
- `--format excalidraw`: Excalidraw JSON only
- `--format both`: draw.io + Excalidraw
- `--type system` *(default)*: full system, all components
- `--type data-flow`: emphasise data movement
- `--type sequence`: Mermaid `sequenceDiagram` for one flow (use with `--flow`)
- `--type infra`: cloud infrastructure resources
- `--flow <name>`: E2E flow to trace when `--type sequence`
- `--output <dir>`: override output directory
- `--fresh`: regenerate from scratch

---

## Notes

- **Always generate the Mermaid preview** regardless of `--format`.
- Diagrams show components and connections — not internal functions or classes.
- Edge labels: concise protocol + key detail.
- If >30 nodes: produce two diagrams — full component diagram + simplified critical-path view.
