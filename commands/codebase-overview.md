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

  If the file already exists, it uses git to detect what changed since the last
  update (based on the "Last updated" timestamp in the file) and only re-explores
  the files that changed — much faster than a full re-index. Falls back to full
  exploration automatically if git is unavailable or changes are too broad.

  Unchanged sections keep their existing wording.

OPTIONS
  --output <path>             Override output path (default: docs/codebase-overview.md)
  --focus <area>              Give extra depth to one area, e.g. --focus "async pipeline"
  --fresh                     Skip merge and git optimisation — full re-index from scratch
  --code-only                 Skip all docs/ files except codebase-overview.md itself;
                              derive everything purely from codebase exploration
  --with-diagram              Also generate docs/architecture.drawio + Mermaid preview
  --with-diagram=excalidraw   Also generate docs/architecture.excalidraw + Mermaid preview
  --with-diagram=both         Generate draw.io + Excalidraw + Mermaid preview
  --help, -h                  Show this help and exit

EXAMPLES
  /codebase-overview
  /codebase-overview --fresh
  /codebase-overview --code-only
  /codebase-overview --code-only --fresh
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
- **If it DOES exist** → read it in full, extract the `Last updated` date from the first line, then proceed to Step 1.5. You will merge rather than replace.
- **If `--fresh` was passed** → skip Step 1.5 entirely. Go straight to Step 2.

### Step 1.5 — Git-accelerated change detection

> Skip this step entirely if: `--fresh` was passed, `--code-only` was passed, or no existing file was found.

This step uses git to discover exactly what changed since the last doc update — so exploration can target only what's new instead of re-reading the whole codebase.

**1. Extract the last-updated date**

Parse the `<!-- Last updated: YYYY-MM-DD -->` line from the existing file.

If the line is missing or the date cannot be parsed → **fall back to full exploration** (proceed to Step 2 as normal; log: `"Could not parse Last updated date — falling back to full exploration"`).

**2. Get commits since that date**

Run:
```bash
git log --since="LAST_UPDATED_DATE" --oneline
```

Handle each outcome:

| Outcome | Action |
|---------|--------|
| `git` not available | Fall back to full exploration. Log: `"git not available — falling back to full exploration"` |
| Not a git repo | Fall back to full exploration. Log: `"Not a git repo — falling back to full exploration"` |
| Command fails for any other reason | Fall back to full exploration. Log the error. |
| **Zero commits returned** | Doc is current. Skip Steps 2–5. Go straight to Step 6 (merge with no new content) and Step 7 (update the date). Print: `"No commits since LAST_UPDATED_DATE — doc is current. Refreshing date only."` |
| One or more commits returned | Continue to step 3 below. |

**3. Analyse changed files**

Run:
```bash
git log --since="LAST_UPDATED_DATE" --name-only --pretty=format:""
```

This gives the list of all files changed across those commits. Deduplicate and strip blank lines.

Also capture commit messages for intent:
```bash
git log --since="LAST_UPDATED_DATE" --pretty=format:"%s"
```

**4. Decide: targeted or full exploration**

Count the number of **distinct packages** changed (i.e., unique parent directories of changed files, e.g. `internal/deliveries`, `cmd/lambdas/webhook-call`, `internal/domain`).

| Condition | Mode |
|-----------|------|
| 0 files changed | Skip exploration — doc is current (handled above) |
| 1–20 files changed AND ≤5 distinct packages | **Targeted mode** (Step 4 — targeted variant) |
| >20 files changed OR >5 distinct packages | **Full exploration** (Step 4 — full variant). Log: `"N files across M packages changed — using full exploration for accuracy"` |
| Any change to a core hub file (e.g. `go.mod`, the primary domain model file, `main.go` for the web service) | **Full exploration** — changes here may cascade into every section |

**5. Map changed files to affected doc sections**

When in targeted mode, use this mapping to know which sections of the doc need updating. You do not need to re-read files that feed into unaffected sections.

| Changed file pattern | Sections likely affected |
|----------------------|--------------------------|
| `internal/domain/*.go` | Domain Models, State Machine Reference, Tricky Parts |
| `internal/rest/*.go`, `openapi/*.yml` | E2E Flows, Component Map, Key File Quick Reference |
| `internal/**/repo.go`, DynamoDB/DB config | Data Layer, E2E Flows |
| `cmd/lambdas/**` | Component Map, Repository Layout, E2E Flows |
| `internal/config/**` | Data Layer (configuration table) |
| `cmd/services/**` | Component Map, Repository Layout |
| New top-level directories | Repository Layout, Component Map |
| `go.mod` changes | Architecture Patterns (new dependencies) — trigger full exploration |

Record: `affectedSections = [list of sections that need re-reading]`.

The targeted exploration in Step 4 will focus on the changed files and the sections they affect. Sections not in `affectedSections` keep their existing content verbatim.

### Step 2 — Read existing docs

**If `--code-only` was passed:** skip this step entirely. Do not read any files in `docs/` (other than `codebase-overview.md` itself, which was already read in Step 1 for merge purposes). Rely solely on codebase exploration. This is useful when existing docs are outdated, incomplete, or potentially misleading.

**Otherwise:** read the following (if present) so the new doc complements rather than duplicates them:
- `CLAUDE.md` / `README.md`
- All other files in `docs/` (excluding `codebase-overview.md` — already read in Step 1)

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

### Step 4 — Explore the codebase

There are two modes depending on the outcome of Step 1.5.

---

#### Mode A — Full exploration (first run, `--fresh`, `--code-only`, or too many changes)

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

---

#### Mode B — Targeted exploration (git-accelerated refresh with ≤20 files / ≤5 packages changed)

Use an Explore subagent with a scoped prompt. The prompt must include:

1. **The list of changed files** (from Step 1.5) — explore these files and their immediate neighbours (files in the same package / directory).

2. **The commit messages** (from Step 1.5) — use these to understand intent before reading the files. A commit message like `"Add GetDeliveries endpoint"` tells you exactly which section needs updating before reading a single byte of code.

3. **The affected sections** (from the Step 1.5 mapping) — explicitly name which doc sections are in scope. For example: `"Focus on Domain Models and E2E Flows — the Data Layer and Testing sections are not affected by these changes."`

4. **What to produce** — for each affected section, produce updated content that can be merged into the existing doc. Be explicit: `"For unchanged sections, output nothing — the existing text is already correct."`

The Explore subagent should NOT try to cover the whole codebase in targeted mode. It reads only the changed files and their direct dependencies.

**When targeted exploration is insufficient** (subagent flags that a changed file pulls in broad context, or commit messages suggest a cross-cutting refactor): escalate to full exploration automatically. Log: `"Targeted exploration insufficient — escalating to full exploration"`.

---

After Step 4 completes (in either mode), proceed to Step 5.

### Step 5 — Generate the new content

**Full exploration mode**: Produce content covering all required sections (see below). Always use concrete `file.go: FunctionName()` references; engineers should be able to navigate directly to the code.

**Targeted exploration mode**: Produce updated content **only for the sections listed in `affectedSections`** (from Step 1.5). For all other sections, carry forward the existing text verbatim — do not regenerate them and do not mark them with `<!-- verify -->` unless you have a specific reason to doubt them. Targeted updates should feel like a surgical diff, not a rewrite.

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
- `--code-only`: Skip reading all files in `docs/` (except `codebase-overview.md` itself). Rely purely on codebase exploration. Use this when existing docs are outdated or you want an unbiased view from the code alone.
- `--with-diagram`: After writing the overview, also generate architecture diagram files. Generates `docs/architecture.drawio` + `docs/architecture-diagram.md` (Mermaid preview)
- `--with-diagram=excalidraw`: Same as above but generate `docs/architecture.excalidraw` instead of draw.io
- `--with-diagram=both`: Generate draw.io + Excalidraw + Mermaid preview

## Examples

### Example 1: First-time generation
When the user says "/codebase-overview" and no overview file exists, explore the codebase and create `docs/codebase-overview.md` with today's date in the `Last updated` line.

### Example 2: Refreshing an existing doc (git-accelerated)
When the user says "/codebase-overview" and `docs/codebase-overview.md` already exists:
1. Extract the `Last updated` date from the file header.
2. Run `git log --since="<date>" --oneline` to find commits since then.
3. **If no commits**: print `"No commits since <date> — doc is current. Refreshing date only."` Update only the `Last updated` date and write the file. Done.
4. **If few commits (≤20 files, ≤5 packages)**: run targeted exploration on only the changed files. Use commit messages to understand intent. Update only the affected doc sections. Merge and write.
5. **If many commits or git unavailable**: fall back to full exploration. Log why. Merge and write.

### Example 3: Force fresh (skip git optimisation)
When the user says "/codebase-overview --fresh", skip Step 1.5 entirely. Ignore the existing file and run full codebase exploration from scratch.

### Example 4: Custom output path
When the user says "/codebase-overview --output docs/architecture.md", use that path for both the existence check and the output.

### Example 5: Focused depth
When the user says "/codebase-overview --focus 'event pipeline'", give extra depth to async/event-driven flows while still covering all required sections.

### Example 6: Code-only — ignore existing docs
When the user says "/codebase-overview --code-only", skip reading any files in `docs/` (other than `codebase-overview.md` itself for merge). Explore the codebase directly and derive all content purely from the source code. Use this when existing docs may be outdated, incomplete, or you want an unbiased view from the code alone.

### Example 7: Code-only fresh start
When the user says "/codebase-overview --code-only --fresh", ignore all existing docs AND skip the merge — write a completely new file derived purely from the codebase.

### Example 8: Overview + diagram in one shot (draw.io)
When the user says "/codebase-overview --with-diagram", generate the full `docs/codebase-overview.md` then immediately generate `docs/architecture.drawio` and `docs/architecture-diagram.md` using the freshly written overview as input. No second codebase exploration needed.

### Example 9: Overview + both diagram formats
When the user says "/codebase-overview --with-diagram=both", generate the overview then generate `docs/architecture.drawio`, `docs/architecture.excalidraw`, and `docs/architecture-diagram.md`.

## Notes

- The `<!-- Last updated: YYYY-MM-DD -->` line must always be the first line of the output file.
- **Git acceleration is the default for refreshes.** It should feel fast — targeted mode reads only the changed files, not the whole codebase. All fallback paths lead to full exploration automatically; the user never needs to know which mode ran.
- **Always log the mode used** (targeted / full / date-only) so the user knows what happened.
- **The ID/Key System section is the most valuable section for new engineers**; invest extra effort here.
- E2E flow traces must include async continuations (e.g. "HTTP 201 returned immediately; async pipeline continues via DynamoDB stream → …").
- Tricky Parts should explain the *why*, not just describe *what* the code does.
- The document should be useful to someone who has never seen the codebase AND to someone debugging a production incident at 2 AM.
- If `docs/` does not exist, create it.
- Use GitHub-Flavored Markdown with ASCII diagrams — no external diagram dependencies.
- When merging, never silently delete existing nuances/gotchas — they were written for a reason. Use `<!-- verify -->` if unsure.
- In targeted mode, do NOT regenerate sections that are not in `affectedSections`. Carry them forward verbatim. A targeted refresh that rewrites everything defeats the purpose.