# Making Atlas Agent-Agnostic

This guide explains how Atlas is structured to work with any AI agent, and how to add support for a new agent.

---

## The problem

AI agents differ in how they load and trigger commands:

| Agent | Commands | Skills / Tools |
|-------|----------|---------------|
| Claude Code | `~/.claude/commands/*.md` | `~/.claude/skills/*/SKILL.md` |
| Cursor | `.cursor/rules/*.mdc` | N/A (rules are always active) |
| GitHub Copilot | `.github/copilot-instructions.md` | N/A |
| Windsurf | `.windsurfrules` | N/A |
| MCP server | Tool definitions in server code | Tool handlers in server code |

If Atlas only shipped files in Claude Code's format, it would be useless to Cursor users — even though the underlying logic (index a codebase, detect git changes, write docs) is completely agent-agnostic.

---

## The solution: spec + integrations

Atlas separates **what to do** from **how to trigger it**:

```
spec/                          ← pure logic, no agent assumptions
├── commands/
│   ├── codebase-overview.md
│   ├── ask-atlas.md
│   ├── ml-overview.md
│   ├── architecture-diagram.md
│   └── ecosystem-overview.md
└── skills/
    ├── detect-git-changes.md
    ├── index-codebase.md
    ├── write-overview-doc.md
    ├── generate-diagram.md
    └── explore-repo-interface.md

integrations/
└── claude-code/               ← Claude Code wrapper (ships today)
    ├── commands/              ← adds frontmatter + slash command trigger
    ├── skills/                ← adds frontmatter + allowed-tools
    └── install.sh
```

- **`spec/`** contains the canonical logic. Written in plain markdown. No frontmatter. No tool-name assumptions (`"read the file"` instead of `"use the Read tool"`). Any LLM can follow these instructions.
- **`integrations/<agent>/`** contains thin wrappers that adapt the spec for a specific agent. The wrapper adds whatever metadata the agent needs (frontmatter, file naming conventions, trigger mechanism).

---

## What makes a spec file agent-agnostic

### 1. No frontmatter

Claude Code uses a YAML frontmatter block to register commands and declare allowed tools:

```markdown
---
name: codebase-overview
description: ...
allowed-tools: Read Glob Grep Bash Write Edit
---
```

Spec files have none of this. They start directly with the `#` heading.

### 2. Neutral tool language

Avoid naming specific agent tools. Use action-oriented language instead:

| Agent-specific | Agent-agnostic |
|---|---|
| `use the Read tool to open the file` | `read the file` |
| `use Glob to find matching files` | `find files matching the pattern` |
| `use Grep to search file contents` | `search file contents for` |
| `use Bash to run` | `run the shell command` |
| `use the Write tool` | `write the file` |

### 3. No slash-command syntax in examples

Use the command name without a slash prefix in spec files:

```
# spec file — agent-agnostic
codebase-overview --fresh
ask-atlas "how does auth work?"
```

Integration files can add the `/` prefix for agents that use it.

### 4. Skill references point to spec

When a command calls a skill, reference the spec path:

```markdown
Follow the instructions in `spec/skills/detect-git-changes.md`.
```

Integration wrappers can rewrite these references if needed.

---

## Anatomy of a Claude Code integration file

The Claude Code integration for a command is the spec content with two additions:

**1. Frontmatter block at the top:**
```markdown
---
name: codebase-overview
description: One-line description for the /codebase-overview slash command.
allowed-tools: Read Glob Grep Bash Write Edit
---
```

- `name`: the slash command name (user types `/codebase-overview`)
- `description`: shown in the command picker
- `allowed-tools`: restricts which tools this command may use

**2. Slash-command syntax in examples:**
```markdown
/codebase-overview --fresh
/ask-atlas "how does auth work?"
```

Everything else is identical to the spec.

---

## Adding a new agent integration

### Step 1 — Understand your agent's format

Find out how your agent loads instructions. Common patterns:

| Agent | Where to put files | Format |
|---|---|---|
| Cursor | `.cursor/rules/` | `.mdc` files with optional frontmatter |
| Copilot | `.github/copilot-instructions.md` | Single markdown file |
| Windsurf | `.windsurfrules` | Plain markdown, concatenated |
| Custom agent | Wherever it reads context from | Agent-specific |

### Step 2 — Create the integration directory

```
integrations/
└── your-agent/
    ├── commands/       (if the agent supports discrete commands)
    ├── skills/         (if the agent supports reusable skill loading)
    └── install.sh      (or install.ps1 / install.py — whatever fits)
```

### Step 3 — Wrap each spec file

For each file in `spec/commands/` and `spec/skills/`:

1. Copy the spec content
2. Add whatever wrapper your agent requires (frontmatter, file extension, naming convention)
3. Replace skill references (`spec/skills/X.md`) with your agent's equivalent path
4. Replace tool language if your agent uses different terminology

**Example — Cursor `.mdc` wrapper for `codebase-overview`:**
```markdown
---
description: Generate or refresh codebase docs
globs: ["**/*"]
alwaysApply: false
---

# Codebase Overview

[paste spec content here, with tool language adapted for Cursor]
```

### Step 4 — Write an install script

The install script should copy your integration files to wherever the agent expects them. See `integrations/claude-code/install.sh` as a reference.

### Step 5 — Update the root `install.sh`

Add your integration as an option:

```bash
# in root install.sh
case "$INTEGRATION" in
  claude-code) source integrations/claude-code/install.sh ;;
  cursor)      source integrations/cursor/install.sh ;;
  *)           echo "Unknown integration: $INTEGRATION" ;;
esac
```

---

## MCP server path

The MCP (Model Context Protocol) approach goes further: instead of instructing the agent to do file I/O and git operations itself, an MCP server exposes those as callable tools.

```
atlas_check_docs()           → { exists, stale, last_updated }
atlas_detect_changes()       → { mode, changed_files, affected_sections }
atlas_read_docs(names[])     → { file: content, ... }
atlas_read_files(paths[])    → { file: content, ... }
atlas_write_doc(path, text)  → { success }
```

With MCP, the agent calls tools instead of following markdown instructions. The spec files become the spec for what each tool should do. This is the most portable path — MCP is supported by Claude, Cursor, Windsurf, and other agents — but requires writing real server code rather than markdown.

---

## Summary

| Layer | Location | Agent-specific? | Purpose |
|---|---|---|---|
| Spec | `spec/` | No | Canonical logic every integration derives from |
| Integration | `integrations/<agent>/` | Yes | Thin wrapper: frontmatter, naming, tool language |
| Installer | `integrations/<agent>/install.sh` | Yes | Copies files to where the agent expects them |
| Root installer | `install.sh` | No | Delegates to `integrations/claude-code/` by default |
