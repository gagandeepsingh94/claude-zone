# Atlas

> Codebase intelligence for AI agents — orientation for new engineers, living reference for veterans.

Atlas gives AI agents a persistent, structured understanding of your codebase. Instead of re-reading source files from scratch every time, the agent builds a machine-readable index once and refreshes only what changed. The result: faster, more accurate answers about architecture, flows, and impact — whether you just joined the team or have been shipping for years.

Atlas ships with a **Claude Code integration** today. The core logic lives in agent-agnostic specs under `spec/` — see [`docs/agent-agnostic-guide.md`](docs/agent-agnostic-guide.md) to add support for Cursor, Copilot, Windsurf, or any other agent.

---

## Motivation

AI agents are powerful but stateless. Every new session, the agent re-reads your codebase from scratch — exploring files, inferring structure, rebuilding context it already had yesterday. On a large repo that's expensive, slow, and inconsistent: two runs over the same code can produce meaningfully different answers.

Atlas is built around a different idea: **pay the exploration cost once, answer cheaply forever.**

The first run is thorough — Atlas explores the codebase, builds a machine-readable index, and writes structured docs. Every subsequent run is incremental: git tells Atlas what changed, and only the affected sections are regenerated. The rest is carried forward verbatim.

More precisely, Atlas introduces **reproducible structure** into AI-generated documentation:

- **The exploration path is rule-governed.** The agent reads specific files in a specific order, not whatever it feels like exploring.
- **The refresh logic is deterministic.** Changed ≤20 files across ≤5 packages → targeted refresh. Hub file changed → full re-index. Same inputs, same decision, every time.
- **The output schema is fixed.** Docs are always written into the same 11 sections, in the same format, so diffs are meaningful and targeted updates are possible.
- **The agent's non-determinism is contained.** Claude fills in the prose, but it fills it into a deterministic container — the structure doesn't drift between runs.

This isn't "deterministic AI" — the words Claude writes will vary. But the *workflow* behaves like a build system: incremental, reproducible, and scoped to what actually changed.

The `ask-atlas` command takes this further. Once docs exist, questions about the codebase are answered from the pre-built docs alone — no re-traversal, no re-inference, minimal tokens. The index is the cache; the docs are the materialized view.

---

## What it does

Atlas is a two-layer system of **commands** and **skills**. The Claude Code integration ships today; other agents can be added by following the guide in [`docs/agent-agnostic-guide.md`](docs/agent-agnostic-guide.md).

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
integrations/claude-code/commands/codebase-overview.md    ← /codebase-overview
  └─ skills/detect-git-changes/        ← activates automatically
  └─ skills/index-codebase/            ← activates automatically
  └─ skills/write-overview-doc/        ← activates automatically
  └─ skills/generate-diagram/          ← activates (if --with-diagram)

integrations/claude-code/commands/ask-atlas.md             ← /ask-atlas
  └─ skills/detect-git-changes/        ← staleness check
  └─ commands/codebase-overview.md     ← delegates to if docs missing or --fresh

integrations/claude-code/commands/architecture-diagram.md  ← /architecture-diagram
  └─ skills/generate-diagram/          ← activates automatically

integrations/claude-code/commands/ecosystem-overview.md    ← /ecosystem-overview
  └─ skills/explore-repo-interface/    ← activates per repo
  └─ skills/generate-diagram/          ← activates automatically

integrations/claude-code/commands/ml-overview.md           ← /ml-overview
  (uses index fast-path if available)
```

---

## File structure

```
atlas/
├── spec/                              # Agent-agnostic logic (source of truth)
│   ├── commands/
│   │   ├── codebase-overview.md
│   │   ├── ask-atlas.md
│   │   ├── architecture-diagram.md
│   │   ├── ecosystem-overview.md
│   │   └── ml-overview.md
│   └── skills/
│       ├── detect-git-changes.md
│       ├── index-codebase.md
│       ├── write-overview-doc.md
│       ├── generate-diagram.md
│       └── explore-repo-interface.md
├── integrations/
│   └── claude-code/                   # Claude Code wrapper (what gets installed)
│       ├── commands/                  # Spec + Claude frontmatter
│       ├── skills/                    # Spec + Claude frontmatter
│       └── install.sh
├── docs/
│   └── agent-agnostic-guide.md        # How to add a new agent integration
├── install.sh                         # Delegates to integrations/claude-code by default
└── README.md
```

---

## Installation

### Global install (available in every project)

```bash
curl -fsSL https://raw.githubusercontent.com/gagandeepsingh94/atlas/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/gagandeepsingh94/atlas.git
cd atlas
./install.sh
```

Installs the Claude Code integration by default. Prints a confirmation:

```
Atlas installed successfully.
  Commands : 5  →  /Users/you/.claude/commands
  Skills   : 5  →  /Users/you/.claude/skills

Available commands:
  /ask-atlas
  /architecture-diagram
  /codebase-overview
  /ecosystem-overview
  /ml-overview
```

### Per-repo install (available only in one project)

```bash
./install.sh --per-repo
```

Or point it at a specific repo:

```bash
./install.sh --per-repo --repo=/path/to/your-repo
```

Then commit `.claude/` so the whole team gets Atlas automatically:

```bash
git add .claude/
git commit -m "Add Atlas commands and skills"
```

### Other agents

Atlas ships with a Claude Code integration today. To add support for another agent (Cursor, Copilot, Windsurf, etc.), see [`docs/agent-agnostic-guide.md`](docs/agent-agnostic-guide.md). The core logic lives in `spec/` and requires only a thin wrapper to work with any agent.

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
