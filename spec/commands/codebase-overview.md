# Command: Codebase Overview

Orchestrates a full or targeted exploration of the current service codebase, producing (or refreshing) `docs/codebase-overview.md` and `docs/codebase-index.json`.

## Skills used

| Step | Skill | Purpose |
|------|-------|---------|
| 2 | `detect-git-changes` | Determine what changed since last update |
| 3 | `index-codebase` | Build or update the structured codebase index |
| 4 | `write-overview-doc` | Write the human-readable overview from the index |
| 5 | `generate-diagram` | *(only with `--with-diagram`)* Produce architecture diagram files |
| 6 | `ml-overview` command | Run ML deep-dive when ML detected or --with-ml |

---

## Step 0 — Handle `--help`

If the user passes `--help` or `-h`, print the following and do nothing else:

```
codebase-overview — Generate or refresh a comprehensive codebase overview

USAGE
  codebase-overview [options]

DESCRIPTION
  Explores the current repo and writes:
    docs/codebase-index.json      Structured machine-readable codebase map
    docs/codebase-overview.md     Human-readable architecture reference

  On refresh: uses git to detect what changed since the last update. If changes
  are small (≤20 files, ≤5 packages), only the affected doc sections are
  regenerated — targeted mode is much faster than a full re-index.

  Falls back to full exploration automatically if git is unavailable or changes
  are too broad.

OPTIONS
  --output <path>             Override output path (default: docs/codebase-overview.md)
  --focus <area>              Give extra depth to one area, e.g. --focus "async pipeline"
  --fresh                     Skip git optimisation — full re-index from scratch
  --code-only                 Derive everything from codebase; skip reading existing docs/
  --with-diagram              Also generate docs/architecture.drawio + Mermaid preview
  --with-diagram=excalidraw   Also generate docs/architecture.excalidraw + Mermaid preview
  --with-diagram=both         Generate draw.io + Excalidraw + Mermaid preview
  --with-ml               Also run ml-overview (forced, even if no ML detected)
  --no-ml                 Skip ml-overview even if ML artifacts are detected
  --help, -h                  Show this help and exit

OUTPUT FILES (default)
  docs/codebase-index.json        Always written / updated
  docs/codebase-overview.md       Always written / updated
  docs/architecture.drawio        (only with --with-diagram)
  docs/architecture-diagram.md    (only with --with-diagram)
  docs/architecture.excalidraw    (only with --with-diagram=excalidraw or =both)
  docs/ml-overview.md     (when ML detected or --with-ml, unless --no-ml)

RELATED SKILLS
  ml-overview            — ML-specific deep dive (models, training, data, serving)
  architecture-diagram   — Generate diagram independently or in a different format
  ecosystem-overview     — Map interactions across multiple repos
```

---

## Step 1 — Detect existing files

Check for:
- `docs/codebase-index.json` — the structured index
- `docs/codebase-overview.md` (or `--output` path) — the human-readable doc

Record which exist. This determines the starting mode.

**If `--fresh` was passed:** skip Step 2 entirely. Go straight to Step 3 in full mode.

---

## Step 2 — Run the `detect-git-changes` skill

> Skip this step if `--fresh` was passed or if neither the index nor overview doc exists.

Follow the instructions in `spec/skills/detect-git-changes.md`.

The skill returns one of:

| Result | Action |
|--------|--------|
| `mode: "current"` | Doc is up to date. Skip Steps 3–4. Update the `Last updated` date in the overview doc and the `generated_at` in the index. Print: `"No commits since <date> — doc is current. Refreshing date only."` Done. |
| `mode: "targeted"` | Proceed to Step 3 in targeted mode with the returned `changed_files` and `affected_sections`. |
| `mode: "full"` | Proceed to Step 3 in full mode. Log the reason returned by the skill. |

---

## Step 3 — Run the `index-codebase` skill

Follow the instructions in `spec/skills/index-codebase.md`.

**Full mode** (first run, `--fresh`, or `detect-git-changes` returned `full`):
- Run Mode A (full index) from the index-codebase skill
- Index all files in the codebase

**Targeted mode** (`detect-git-changes` returned `targeted`):
- Run Mode B (targeted update) from the index-codebase skill
- Pass `--files <changed_files>` (the list from detect-git-changes)

**`--code-only` flag:** if passed, do not read any existing files in `docs/` (other than `codebase-index.json` itself) during indexing. Derive everything from codebase exploration only.

---

## Step 4 — Run the `write-overview-doc` skill

Follow the instructions in `spec/skills/write-overview-doc.md`.

**Full mode:**
- Run with no `--sections` flag — generate all required sections

**Targeted mode:**
- Pass `--sections <affected_sections>` (from the detect-git-changes result)
- All other sections are carried forward verbatim from the existing overview doc

**`--output` flag:** pass through to the skill.
**`--focus` flag:** pass through to the skill.
**`--fresh` flag:** pass through to the skill.

---

## Step 5 — Run the `generate-diagram` skill *(only if `--with-diagram` was passed)*

Follow the instructions in `spec/skills/generate-diagram.md`.

Map flags:
- `--with-diagram` → `--format drawio`
- `--with-diagram=excalidraw` → `--format excalidraw`
- `--with-diagram=both` → `--format both`

The skill reads `docs/codebase-index.json` as its input — no second codebase exploration needed.

After the diagram is written, add a cross-reference to `docs/architecture-diagram.md` in the companion docs block at the top of `docs/codebase-overview.md`.

---

## Step 6 — ML artefact detection and ml-overview

Scan the repo for ML signals:
- Model files: `*.pt`, `*.pth`, `*.ckpt`, `*.pb`, `*.h5`, `*.onnx`, `*.pkl`, `*.safetensors`
- ML imports: `torch`, `tensorflow`, `sklearn`, `xgboost`, `transformers`, `jax`, `lightgbm`
- Training scripts: `train.py`, `fit.py`, files with `trainer` in the name
- Experiment tracking: `mlflow`, `wandb`, `comet_ml`, `neptune`
- Notebooks: `*.ipynb`

**Decision logic:**

| Condition | Action |
|-----------|--------|
| `--no-ml` passed | Skip this step entirely. |
| ML artifacts found OR `--with-ml` passed | Follow all steps in the `ml-overview` command. Pass through `--output`, `--focus`, `--fresh` if provided. |
| No ML artifacts and no `--with-ml` | Skip. |

When ml-overview runs:
- It will read `docs/codebase-index.json` (just written in Step 3) to fast-path artifact detection — no redundant scan.
- After it completes, add a cross-reference line near the top of `docs/codebase-overview.md`:
  `> **ML overview:** see [docs/ml-overview.md](docs/ml-overview.md)`

---

## Examples

### First-time generation
`codebase-overview` with no existing files → full index → full overview doc.

### Git-accelerated refresh
`codebase-overview` with existing index + overview → detect-git-changes → targeted index update → targeted overview update. Only changed sections rewritten.

### Force fresh
`codebase-overview --fresh` → skip git detection → full re-index → full overview rewrite.

### Focused depth
`codebase-overview --focus "event pipeline"` → passes `--focus` through to write-overview-doc skill.

### Overview + diagram in one shot
`codebase-overview --with-diagram` → full flow + generate-diagram skill at the end.

### Code-only fresh start
`codebase-overview --code-only --fresh` → ignore all existing docs, derive purely from source code.

---

## Notes

- **Always log the mode used** (targeted / full / date-only) so the user knows what happened.
- **`docs/codebase-index.json` is always written**, even on a targeted refresh. It is the long-term persistent state for this command.
- **Git acceleration is the default for refreshes.** Targeted mode reads only changed files — it should feel fast. Full fallback is automatic when needed.
- If `docs/` does not exist, create it.
- The `<!-- Last updated: YYYY-MM-DD -->` line must always be the first line of the overview doc.
