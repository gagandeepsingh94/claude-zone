---
description: Deeply explore a service codebase and generate (or refresh) a comprehensive codebase-overview.md covering architecture, E2E flows with code paths, and non-obvious nuances.
---

# Codebase Overview Generator

Deeply explore the current service codebase and produce (or intelligently update) a thorough `docs/codebase-overview.md` document.

## Purpose

Produces a single reference document that gives any engineer an immediate bird's-eye view of the service: what it does, how its pieces fit together, every significant E2E flow traced to concrete file paths, and the tricky/non-obvious parts that are easy to get wrong.

## Instructions

### Step 0 — Handle `--help`

If the user passes `--help` or `-h`, print the following and do nothing else:

```
/codebase-overview — Generate or refresh a comprehensive codebase overview doc

USAGE
  /codebase-overview [options]

DESCRIPTION
  Deeply explores the current repo and writes docs/codebase-overview.md covering:
  repository layout, component map, domain models, ID/key system, E2E flows with
  code paths, architecture patterns, data layer, tricky nuances, state machines,
  testing approach, and a key file quick reference.

  If the file already exists, it merges new findings into the existing doc rather
  than overwriting it. Unchanged sections keep their existing wording.

OPTIONS
  --output <path>             Override output path (default: docs/codebase-overview.md)
  --focus <area>              Give extra depth to one area, e.g. --focus "async pipeline"
  --fresh                     Skip merge — write a completely new file from scratch
  --with-diagram              Also generate docs/architecture.drawio + Mermaid preview
  --with-diagram=excalidraw   Also generate docs/architecture.excalidraw + Mermaid preview
  --with-diagram=both         Generate draw.io + Excalidraw + Mermaid preview
  --help, -h                  Show this help and exit

EXAMPLES
  /codebase-overview
  /codebase-overview --fresh
  /codebase-overview --focus "event pipeline"
  /codebase-overview --with-diagram
  /codebase-overview --with-diagram=both --fresh

OUTPUT FILES (default)
  docs/codebase-overview.md
  docs/architecture.drawio        (only with --with-diagram)
  docs/architecture-diagram.md    (only with --with-diagram)
  docs/architecture.excalidraw    (only with --with-diagram=excalidraw or =both)

RELATED SKILLS
  /ml-overview            — ML-specific deep dive (models, training, data, serving)
  /architecture-diagram   — Generate diagram independently or in a different format
  /ecosystem-overview     — Map interactions across multiple repos
```

### Step 1 — Detect existing overview

Check whether `docs/codebase-overview.md` (or the `--output` path) already exists.

- **If it does NOT exist** → proceed to Step 2 (fresh generation).
- **If it DOES exist** → read it in full, note the `Last updated` line at the top, then proceed to Step 2. You will merge rather than replace.

### Step 2 — Read existing docs

Read the following (if present) so the new doc complements rather than duplicates them:
- `CLAUDE.md` / `README.md`
- All other files in `docs/`

### Step 3 — Detect ML artefacts

Before exploring, scan the repo for signals of ML code:
- Model files: `*.pt`, `*.pth`, `*.ckpt`, `*.pb`, `*.h5`, `*.onnx`, `*.pkl`, `*.safetensors`
- ML imports: `torch`, `tensorflow`, `sklearn`, `xgboost`, `transformers`, `jax`, `lightgbm`
- Training scripts: `train.py`, `fit.py`, files with `trainer` in the name
- Experiment tracking: `mlflow`, `wandb`, `comet_ml`, `neptune`
- Data versioning: `dvc.yaml`, `*.dvc`
- Notebooks: `*.ipynb`

**If ML artefacts are found:** note this clearly. Do not cover ML topics in depth here — instead add a callout box near the top of the generated doc:

```
> **ML components detected.** This repo contains machine learning code.
> Run `/ml-overview` to generate `docs/ml-overview.md` with full coverage of
> model types, training pipelines, data sources, experiment tracking, and serving.
```

Cross-reference `docs/ml-overview.md` in the companion docs block at the top of the file (if it exists) or note it as a recommended next step.

### Step 4 — Explore the codebase thoroughly

Use an Explore subagent to cover:
- Full directory layout and what each top-level folder contains
- All executable entry points (`cmd/` or equivalent)
- Domain / data models — key structs, enums, lifecycle states, relationships
- API/handler layer — routes, middleware, auth, request/response flow
- Repository / data-access layer — databases, tables, indexes, query patterns
- Async workers / consumers / lambdas — triggers, behaviour, outputs
- External service integrations — protocols, clients, auth, what is sent/received
- Configuration — key environment variables and their defaults
- ID / key system — every identifier type, who creates it, where it's used

### Step 5 — Generate the new content

Produce content covering all required sections (see below). Always use concrete `file.go: FunctionName()` references; engineers should be able to navigate directly to the code.

### Step 6 — Merge with existing file (if one exists)

**Do NOT blindly overwrite.** Instead:

1. For each section in the newly generated content, compare it against the same section in the existing file.
2. Apply these merge rules per section:
   - **Structurally changed** (new components, renamed files, removed flows) → replace with new content.
   - **Additive only** (new nuances, new E2E flows, new tricky parts) → merge new items in; keep existing items that are still accurate.
   - **Unchanged** (same files, same behaviour) → keep existing wording (it may be more polished).
3. If you are uncertain whether an existing nuance/note is still accurate, **keep it** and append `<!-- verify -->` so a human can confirm.
4. Write the merged result to the output file.

### Step 7 — Write the final file

The output file must start with:

```
<!-- Last updated: YYYY-MM-DD -->
```

(Use today's date.)

Then a cross-reference block to companion docs, followed by the full content.

---

## Required Sections

Adapt headings to the service but always include:

- **Repository Layout** — annotated directory tree
- **Component Map** — table of every significant component with purpose
- **Domain Models Deep Dive** — field-level breakdown of core entities, status enums, lifecycle
- **ID / Key System** — comparison table of every identifier (who creates it, where used)
- **E2E Flows with Code Paths** — every significant journey traced with `file.go: Fn()` references, including async continuations
- **Architecture Patterns** — recurring patterns (event-driven, CQRS, optimistic locking, circuit breaker, at-least-once delivery, etc.)
- **Data Layer** — tables/collections, indexes, consistency model, caching
- **Tricky Parts & Nuances** — non-obvious behaviours and design decisions, aim for 8–15 items, always explain the *why*
- **State Machine Reference** — status/state transition diagrams for key entities
- **Testing Approach** — unit vs integration vs E2E, how to run, special patterns
- **Key File Quick Reference** — table of most important files with single-line purpose

---

### Step 8 — Generate architecture diagram (only if `--with-diagram` was passed)

If the user passed `--with-diagram` (optionally with a format: `--with-diagram=excalidraw` or `--with-diagram=both`), execute the full architecture-diagram generation flow immediately after writing the overview file. Use `docs/codebase-overview.md` as the primary input — do not re-explore the codebase.

Follow these steps from the `architecture-diagram` skill:
1. Build the component inventory (nodes + edges + groups) from the freshly written `docs/codebase-overview.md`
2. Assign layout grid positions (Row 0 = actors, Row 1 = API, Row 2 = services/workers, Row 3 = data stores, Row 4 = external)
3. Generate `docs/architecture.drawio` (always)
4. Generate `docs/architecture.excalidraw` only if `--with-diagram=excalidraw` or `--with-diagram=both`
5. Generate Mermaid preview embedded in `docs/architecture-diagram.md` (always)
6. Add `<!-- Last updated: YYYY-MM-DD -->` as first line of `docs/architecture-diagram.md`
7. Cross-reference `docs/architecture-diagram.md` in the companion docs block at the top of `docs/codebase-overview.md`

If `--with-diagram` is passed without a format value, default to draw.io only.

---

## Parameters

- `--output <path>`: Override output file path (default: `docs/codebase-overview.md`)
- `--focus <area>`: Give extra depth to a specific area (e.g. `--focus "async pipeline"`, `--focus "data layer"`)
- `--fresh`: Skip merge logic and write a completely fresh file (existing file is overwritten)
- `--with-diagram`: After writing the overview, also generate architecture diagram files. Generates `docs/architecture.drawio` + `docs/architecture-diagram.md` (Mermaid preview)
- `--with-diagram=excalidraw`: Same as above but generate `docs/architecture.excalidraw` instead of draw.io
- `--with-diagram=both`: Generate draw.io + Excalidraw + Mermaid preview

## Examples

### Example 1: First-time generation
When the user says "/codebase-overview" and no overview file exists, explore the codebase and create `docs/codebase-overview.md` with today's date in the `Last updated` line.

### Example 2: Refreshing an existing doc
When the user says "/codebase-overview" and `docs/codebase-overview.md` already exists, read the existing file, explore the codebase for changes since the last update, merge the results, and update the `Last updated` date.

### Example 3: Force fresh
When the user says "/codebase-overview --fresh", ignore any existing file and write a completely new one.

### Example 4: Custom output path
When the user says "/codebase-overview --output docs/architecture.md", use that path for both the existence check and the output.

### Example 5: Focused depth
When the user says "/codebase-overview --focus 'event pipeline'", give extra depth to async/event-driven flows while still covering all required sections.

### Example 6: Overview + diagram in one shot (draw.io)
When the user says "/codebase-overview --with-diagram", generate the full `docs/codebase-overview.md` then immediately generate `docs/architecture.drawio` and `docs/architecture-diagram.md` using the freshly written overview as input. No second codebase exploration needed.

### Example 7: Overview + both diagram formats
When the user says "/codebase-overview --with-diagram=both", generate the overview then generate `docs/architecture.drawio`, `docs/architecture.excalidraw`, and `docs/architecture-diagram.md`.

## Notes

- The `<!-- Last updated: YYYY-MM-DD -->` line must always be the first line of the output file.
- The ID/Key System section is the most valuable section for new engineers; invest extra effort here.
- E2E flow traces must include async continuations (e.g. "HTTP 201 returned immediately; async pipeline continues via DynamoDB stream → …").
- Tricky Parts should explain the *why*, not just describe *what* the code does.
- The document should be useful to someone who has never seen the codebase AND to someone debugging a production incident at 2 AM.
- If `docs/` does not exist, create it.
- Use GitHub-Flavored Markdown with ASCII diagrams — no external diagram dependencies.
- When merging, never silently delete existing nuances/gotchas — they were written for a reason. Use `<!-- verify -->` if unsure.