# Atlas

> Codebase intelligence for Claude Code — orientation for new engineers, living reference for veterans.

Atlas gives Claude a persistent, structured understanding of your codebase. Instead of re-reading source files from scratch every time, Claude builds a machine-readable index once and refreshes only what changed. The result: faster, more accurate answers about architecture, flows, and impact — whether you just joined the team or have been shipping for years.

---

## What it does

Atlas is a two-layer system of **commands** and **skills** for Claude Code.

**Commands** are predefined slash commands you invoke directly. Each command orchestrates a high-level workflow:

| Command | What it produces |
|---------|-----------------|
| `/codebase-overview` | `docs/codebase-index.json` + `docs/codebase-overview.md` — full architecture reference with git-accelerated refresh |
| `/ask-atlas` | Instant Q&A from pre-built docs — no codebase re-traversal, minimal token usage |
| `/architecture-diagram` | `docs/architecture.drawio` + `docs/architecture-diagram.md` — editable draw.io diagram and Mermaid preview |
| `/ml-overview` | `docs/ml-overview.md` — models, training pipelines, data sources, experiment tracking, serving, monitoring |
| `/ecosystem-overview` | `docs/ecosystem-overview.md` + diagrams — dependency graph and impact analysis across multiple repos |

**Skills** are autonomous capabilities Claude activates on its own (no slash command needed). Commands delegate to skills; skills can also be used independently when Claude decides they're appropriate:

| Skill | What it does |
|-------|-------------|
| `index-codebase` | Builds and maintains `docs/codebase-index.json` — the structured, machine-readable codebase map |
| `detect-git-changes` | Reads git history and the index to determine refresh scope: date-only, targeted, or full |
| `write-overview-doc` | Converts the index into `docs/codebase-overview.md` covering all 11 architecture sections |
| `generate-diagram` | Produces draw.io XML, Excalidraw JSON, and Mermaid diagrams from the index |
| `explore-repo-interface` | Extracts what a repo exposes, depends on, and owns — used for cross-repo analysis |

---

## How it works

### The index is the foundation

When you first run `/codebase-overview`, Atlas explores the repo and writes `docs/codebase-index.json` — a structured map of every file, component, entity, flow, and which documentation section each file feeds into.

```
docs/
  codebase-index.json       ← machine-readable source of truth
  codebase-overview.md      ← human-readable architecture reference
  architecture-diagram.md   ← Mermaid preview (renders in GitHub)
  architecture.drawio       ← editable diagram (diagrams.net / VS Code)
  ml-overview.md            ← ML pipeline documentation (if applicable)
  ecosystem-overview.md     ← cross-repo dependency map (if applicable)
```

### Git-accelerated refresh

On subsequent runs, Atlas doesn't re-read everything. The `detect-git-changes` skill:

1. Reads `git log` since the index was last built
2. Maps each changed file to the doc sections it feeds (using the index's `feeds_sections` data)
3. Returns one of three modes:

| Mode | When | What happens |
|------|------|-------------|
| `current` | No commits since last build | Updates the date only — instant |
| `targeted` | ≤ 20 files changed, ≤ 5 packages | Re-indexes changed files, rewrites only affected sections |
| `full` | Broad changes or git unavailable | Full re-index and full rewrite |

This means a single-file change to your API handler regenerates the "API & Endpoints" section only — not the entire document.

### Commands vs skills

```
commands/codebase-overview.md          ← you type /codebase-overview
  └─ skills/detect-git-changes/        ← Claude activates automatically
  └─ skills/index-codebase/            ← Claude activates automatically
  └─ skills/write-overview-doc/        ← Claude activates automatically
  └─ skills/generate-diagram/          ← Claude activates (if --with-diagram)

commands/ask-atlas.md                  ← you type /ask-atlas
  └─ skills/detect-git-changes/        ← staleness check
  └─ commands/codebase-overview.md     ← delegates to if docs missing or --fresh

commands/architecture-diagram.md       ← you type /architecture-diagram
  └─ skills/generate-diagram/          ← Claude activates automatically

commands/ecosystem-overview.md         ← you type /ecosystem-overview
  └─ skills/explore-repo-interface/    ← Claude activates per repo
  └─ skills/generate-diagram/          ← Claude activates automatically

commands/ml-overview.md                ← you type /ml-overview
  (uses index fast-path if available)
```

---

## File structure

```
atlas/
├── commands/
│   ├── codebase-overview.md      # /codebase-overview command
│   ├── ask-atlas.md              # /ask-atlas command
│   ├── architecture-diagram.md   # /architecture-diagram command
│   ├── ecosystem-overview.md     # /ecosystem-overview command
│   └── ml-overview.md            # /ml-overview command
└── skills/
    ├── index-codebase/
    │   └── SKILL.md
    ├── detect-git-changes/
    │   └── SKILL.md
    ├── write-overview-doc/
    │   └── SKILL.md
    ├── generate-diagram/
    │   └── SKILL.md
    └── explore-repo-interface/
        └── SKILL.md
```

---

## Installation

### Global install (available in every project)

Copy commands and skills into your global Claude Code config directory:

```bash
# Commands — available as /command-name in any project
cp commands/*.md ~/.claude/commands/

# Skills — Claude activates these automatically
cp -r skills/. ~/.claude/skills/
```

After copying, verify:

```
~/.claude/
├── commands/
│   ├── codebase-overview.md
│   ├── ask-atlas.md
│   ├── architecture-diagram.md
│   ├── ecosystem-overview.md
│   └── ml-overview.md
└── skills/
    ├── index-codebase/
    │   └── SKILL.md
    ├── detect-git-changes/
    │   └── SKILL.md
    ├── write-overview-doc/
    │   └── SKILL.md
    ├── generate-diagram/
    │   └── SKILL.md
    └── explore-repo-interface/
        └── SKILL.md
```

### Per-repo install (available only in one project)

Copy into the `.claude/` directory at the root of your repo:

```bash
cd /path/to/your-repo

# Commands
mkdir -p .claude/commands
cp /path/to/atlas/commands/*.md .claude/commands/

# Skills
mkdir -p .claude/skills
cp -r /path/to/atlas/skills/. .claude/skills/
```

Commit `.claude/` to source control so the whole team gets Atlas automatically:

```bash
git add .claude/
git commit -m "Add Atlas codebase intelligence commands and skills"
```

---

## Quick start

### Document a new codebase

```
/codebase-overview
```

Produces `docs/codebase-index.json` and `docs/codebase-overview.md`. On a large repo, expect 2–4 minutes for the first run. Subsequent runs are significantly faster.

### Refresh after a sprint

```
/codebase-overview
```

Same command. Atlas detects what changed via git and runs in targeted mode — only affected sections are rewritten.

### Ask questions from pre-built docs

Once docs exist, skip the indexing step entirely:

```
/ask-atlas "how does the delivery state machine work?"
```

Loads `docs/codebase-overview.md` (and `ml-overview.md`, `architecture-diagram.md` if present) and answers immediately — no codebase traversal. Warns if docs are stale.

```
/ask-atlas --files src/auth/jwt.py "how is the JWT validated?"
```

Adds a specific source file to the context for a more detailed answer.

```
/ask-atlas --fresh
```

Regenerates all docs first, then enters chat mode.

### Generate an architecture diagram

```
/architecture-diagram
```

Produces `docs/architecture.drawio` (open in diagrams.net or the VS Code draw.io extension) and `docs/architecture-diagram.md` (renders as Mermaid in GitHub).

```
/architecture-diagram --format both
```

Produces draw.io + Excalidraw + Mermaid.

```
/architecture-diagram --type sequence --flow "user checkout"
```

Produces a Mermaid sequence diagram for a specific E2E flow.

### Document an ML codebase

```
/ml-overview
```

Covers: model inventory, training pipelines, data sources, feature engineering, experiment tracking, evaluation, serving, monitoring, and reproducibility.

### Map a multi-service system

```
/ecosystem-overview service-a,service-b,service-c
```

Or with a repos file:

```
/ecosystem-overview --repos-file ecosystem-repos.txt
```

Produces a dependency graph, impact analysis, cross-repo E2E flows, and editable diagrams across all repos.

---

## Command reference

### `/ask-atlas`

```
USAGE
  /ask-atlas [question] [options]

OPTIONS
  --files <path1,path2,...>   Include additional source files in context
  --fresh                     Regenerate all docs before answering
  --no-ml                     Skip ml-overview.md even if present
  --help, -h                  Show help
```

### `/codebase-overview`

```
OPTIONS
  --output <path>             Override output path (default: docs/codebase-overview.md)
  --focus <area>              Extra depth on one area, e.g. --focus "async pipeline"
  --fresh                     Skip git optimisation — full re-index from scratch
  --code-only                 Derive everything from code; skip reading existing docs/
  --with-diagram              Also generate docs/architecture.drawio + Mermaid preview
  --with-diagram=excalidraw   Also generate docs/architecture.excalidraw
  --with-diagram=both         Generate draw.io + Excalidraw + Mermaid
  --help, -h                  Show help
```

### `/architecture-diagram`

```
OPTIONS
  --format drawio        draw.io only (default)
  --format excalidraw    Excalidraw only
  --format both          draw.io + Excalidraw
  --type system          Full system, all components (default)
  --type data-flow       Emphasise data movement
  --type sequence        Mermaid sequence diagram for one flow
  --type infra           Cloud infrastructure resources
  --flow <name>          Flow name for --type sequence
  --output <dir>         Override output directory
  --fresh                Regenerate from scratch
  --help, -h             Show help
```

### `/ml-overview`

```
OPTIONS
  --output <path>    Override output path (default: docs/ml-overview.md)
  --focus <area>     Extra depth, e.g. --focus "training pipeline"
  --fresh            Write a completely new file from scratch
  --help, -h         Show help
```

### `/ecosystem-overview`

```
USAGE
  /ecosystem-overview <repo1,repo2,...> [options]
  /ecosystem-overview --repos-file <path> [options]

OPTIONS
  --repos-file <path>    Path to repos list file
  --output <dir>         Override output directory (default: docs/)
  --fresh                Ignore existing output and regenerate
  --no-diagram           Skip diagram files
  --with-excalidraw      Also generate docs/ecosystem.excalidraw
  --focus <area>         Extra depth: impact | data | flows | contracts
  --help, -h             Show help
```

---

## Tips

- **Use `/ask-atlas` for quick questions.** Once docs exist, it's far cheaper than re-running `/codebase-overview` — it reads the pre-built docs and answers immediately without touching source files.
- **Commit `docs/codebase-index.json`.** It's the long-term state that makes targeted refresh possible. Without it, every run is a full re-index.
- **Run `/codebase-overview` before `/architecture-diagram`.** The diagram command is significantly faster and more accurate when the index already exists.
- **For hybrid ML repos**, run both `/codebase-overview` and `/ml-overview`. The codebase overview covers service architecture; the ML overview covers model lifecycle.
- **For a quick visual**, `docs/architecture-diagram.md` renders Mermaid instantly in GitHub — no tool required.
- **For ecosystem analysis**, if any repo already has a `docs/codebase-index.json`, it's used automatically as a fast-path — no re-exploration needed.
