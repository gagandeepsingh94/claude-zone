# Command: Architecture Diagram

Orchestrates architecture diagram generation for the current repository. Reads the best available knowledge source and delegates all diagram production to the `generate-diagram` skill.

## Skills used

| Step | Skill | Purpose |
|------|-------|---------|
| 2 | `generate-diagram` | Produce draw.io / Excalidraw / Mermaid diagram files |

---

## Step 0 — Handle `--help`

If the user passes `--help` or `-h`, print the following and do nothing else:

```
architecture-diagram — Generate an architecture diagram from the current codebase

USAGE
  architecture-diagram [options]

DESCRIPTION
  Reads existing knowledge sources (codebase-index.json preferred, then
  codebase-overview.md, then direct exploration) and generates editable
  architecture diagram files.

  Always produces:
    docs/architecture.drawio       (open in diagrams.net or VS Code draw.io extension)
    docs/architecture-diagram.md   (Mermaid preview — renders in GitHub instantly)

  Optionally produces:
    docs/architecture.excalidraw   (with --format excalidraw or --format both)

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
  --output <dir>         Override output directory (default: docs/)
  --fresh                Ignore existing diagram files and regenerate from scratch
  --help, -h             Show this help and exit

EXAMPLES
  architecture-diagram
  architecture-diagram --format both
  architecture-diagram --type sequence --flow "user checkout"
  architecture-diagram --type data-flow --format excalidraw
  architecture-diagram --type infra --fresh

TIPS
  draw.io:    After opening, press Ctrl+Shift+H (Fit Page). Use Arrange > Layout
              to auto-arrange nodes.
  Excalidraw: Select all (Ctrl+A) and click "Tidy up" in the toolbar.
  Mermaid:    Renders immediately in GitHub — no tool needed.

RELATED SKILLS
  codebase-overview    — Generate the index and overview this diagram is built from
  ecosystem-overview   — Multi-repo diagram across a whole system
```

---

## Step 1 — Determine input source

Check for knowledge sources in priority order:

| Priority | Source | Action |
|----------|--------|--------|
| 1 | `docs/codebase-index.json` | Best source — structured component inventory already extracted |
| 2 | `docs/codebase-overview.md` | Good source — components, integrations, data flows in prose |
| 3 | `docs/ml-overview.md` | Supplement if present — adds ML pipeline components |
| 4 | None of the above | Explore the codebase directly (entry points, clients, DB config, infra files) |

Log which source is being used (e.g. `"Using docs/codebase-index.json as input"`).

If sources 1 and 2 do not exist, print a suggestion:
```
No docs/codebase-index.json or docs/codebase-overview.md found.
Run codebase-overview first for a richer, faster diagram.
Proceeding with direct codebase exploration...
```

---

## Step 2 — Run the `generate-diagram` skill

Follow the instructions in `spec/skills/generate-diagram.md`.

Pass through all user flags:
- `--format <value>` (default: `drawio`)
- `--type <value>` (default: `system`)
- `--flow <name>` (for `--type sequence`)
- `--output <dir>` (default: `docs/`)
- `--fresh`

The skill handles all diagram generation: component inventory extraction, layout grid, draw.io XML, Excalidraw JSON, and Mermaid preview.

---

## Examples

### Quick system overview (draw.io only)
`architecture-diagram` → reads best available source → generates `docs/architecture.drawio` + `docs/architecture-diagram.md`.

### Both formats
`architecture-diagram --format both` → generates draw.io + Excalidraw + Mermaid.

### Sequence diagram for a specific flow
`architecture-diagram --type sequence --flow "delivery creation"` → Mermaid `sequenceDiagram` in `docs/architecture-diagram.md`.

### Data-flow focused
`architecture-diagram --type data-flow` → emphasises data stores, transformation steps, and queues.

### Infrastructure view
`architecture-diagram --type infra` → focuses on cloud resources (Lambda, DynamoDB, SQS, S3, VPC).

---

## Notes

- **Prefer `docs/codebase-index.json` over `docs/codebase-overview.md`.** The index has structured component data already extracted; the overview requires prose parsing.
- **`codebase-overview` is the recommended first step.** Running it first builds both the index and the overview doc, making this command significantly faster and more accurate.
- Mermaid is always the fastest win — if the user just needs a quick visual, the Mermaid in `docs/architecture-diagram.md` renders immediately in GitHub.
