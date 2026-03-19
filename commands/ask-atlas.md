---
name: ask-atlas
description: Answer questions about a codebase using pre-built Atlas docs. Loads docs/codebase-overview.md (and ml-overview.md, architecture-diagram.md if present) then answers questions from those docs only — no codebase re-traversal, minimal token usage. Use when you need quick answers about a codebase that has already been indexed by Atlas.
allowed-tools: Read Glob Bash Write Edit
---

# Command: Ask Atlas

Loads pre-built Atlas docs into context and answers questions about the codebase from those docs only — no source file traversal, minimal token spend.

---

## Step 0 — Handle `--help`

If the user passes `--help` or `-h`, print the following and do nothing else:

```
/ask-atlas — Answer questions about this codebase using pre-built Atlas docs

USAGE
  /ask-atlas [question] [options]

DESCRIPTION
  Loads docs/codebase-overview.md (and ml-overview.md, architecture-diagram.md
  if present) into context, then answers questions from those docs only —
  no codebase re-traversal, minimal token usage.

  If docs don't exist yet, runs /codebase-overview automatically first.
  Warns if docs are stale (commits since last index).

OPTIONS
  --files <path1,path2,...>   Include additional source files in context
  --fresh                     Regenerate all docs before answering
  --no-ml                     Skip ml-overview.md even if present
  --help, -h                  Show this help and exit

EXAMPLES
  /ask-atlas
  /ask-atlas "how does the delivery state machine work?"
  /ask-atlas --files src/auth/jwt.py "how is the JWT validated?"
  /ask-atlas --fresh "what changed recently?"

RELATED COMMANDS
  /codebase-overview    — Generate or refresh the docs this command reads from
  /ml-overview          — Deep-dive ML docs (also loaded automatically if present)
  /architecture-diagram — Generate diagram files
```

---

## Step 1 — Parse inputs

Extract from the invocation:

- **Inline question**: everything that is not a flag or flag argument (e.g. `/ask-atlas "how does auth work?"` → question is `"how does auth work?"`)
- **`--files <path1,path2,...>`**: comma-separated paths relative to the repo root; read each in full during Step 5
- **`--fresh`**: if present, regenerate all docs before entering chat mode
- **`--no-ml`**: if present, skip `docs/ml-overview.md` even if it exists
- **`--help` / `-h`**: handled in Step 0

---

## Step 2 — Check for existing docs

Look for the following files (do NOT Glob or Grep the source tree — only check these exact paths):

1. `docs/codebase-overview.md` ← primary (required)
2. `docs/codebase-index.json` ← used for staleness check
3. `docs/ml-overview.md` ← auto-included if present, unless `--no-ml`
4. `docs/architecture-diagram.md` ← auto-included if present

Record which exist.

---

## Step 3 — Auto-generate if missing (or `--fresh`)

**If `docs/codebase-overview.md` does not exist OR `--fresh` was passed:**

Print:
```
No docs/codebase-overview.md found.
Generating docs now — this takes 2–4 minutes on a large repo.
Running /codebase-overview...
```

Follow all steps in `commands/codebase-overview.md`. After generation completes, continue to Step 4.

**If `docs/codebase-overview.md` exists and `--fresh` was not passed:** skip this step.

---

## Step 4 — Staleness check

**Skip this step if `--fresh` was passed or if docs were just generated in Step 3.**

Run the `detect-git-changes` skill. Use the result to decide what to print:

| Result | Action |
|--------|--------|
| `mode: "current"` | Silent — proceed without printing anything |
| `mode: "targeted"` | Print warning (see below) |
| `mode: "full"` | Print warning (see below) |

**Targeted warning:**
```
⚠ Docs may be slightly stale — N commits since last index (DATE).
  Affected sections: <list>. Run /codebase-overview or /ask-atlas --fresh to update.
```

**Full warning:**
```
⚠ Docs are stale — N commits since last index (DATE).
  Run /codebase-overview or /ask-atlas --fresh for accurate answers.
```

Where N is the count of commits since the last index date, and DATE is the `<!-- Last updated: YYYY-MM-DD -->` date from `docs/codebase-overview.md` (or `meta.generated_at` from `docs/codebase-index.json`).

---

## Step 5 — Load context

Read all available docs using the Read tool. Do NOT use Glob or Grep on source files — only read the specific paths listed here plus any `--files` paths:

1. `docs/codebase-overview.md` (required — always read)
2. `docs/ml-overview.md` (read if it exists and `--no-ml` was not passed)
3. `docs/architecture-diagram.md` (read if it exists)
4. Each file from `--files` (read each in full)

---

## Step 6 — Enter chat mode

After loading context, print a brief confirmation:

```
Atlas loaded. Context: codebase-overview.md [+ ml-overview.md] [+ architecture-diagram.md] [+ N additional files].
Ask me anything about this codebase. I'll answer from the docs above.
To include more detail: /ask-atlas --files src/some/file.py
```

Adjust the bracketed parts to reflect what was actually loaded (omit entries for files that weren't present or loaded).

**If an inline question was provided in Step 1**, answer it immediately after printing the confirmation.

---

## Behavioural constraints — IMPORTANT

These constraints apply for the entire conversation after entering chat mode:

1. **Answer ONLY from the loaded docs and `--files` content.** Do not derive answers from prior knowledge about frameworks or languages unless the docs confirm it.

2. **Do NOT re-explore the codebase.** No Glob, Grep, or Read calls on source files that were not listed in `--files`. The docs are the source of truth.

3. **Stay in chat mode for all follow-up messages.** Do not re-read docs or re-run the staleness check on subsequent questions — the context is already loaded.

4. **If a question cannot be answered from the loaded context**, say so explicitly and suggest next steps:
   ```
   I don't have enough detail on that in the docs.
   Try: /ask-atlas --files <relevant-file> "<your question>"
   Or refresh the docs: /codebase-overview --focus "<area>"
   ```

5. **Never guess file paths or implementation details** not present in the loaded docs. If the docs say a file exists, reference it. If they don't mention it, don't invent it.

---

## Examples

### Repo with no docs
`/ask-atlas "what does this repo do?"` → auto-generates docs → answers question.

### Repo with fresh docs
`/ask-atlas "explain the data layer"` → loads docs → answers immediately, no codebase scan.

### Stale docs
`/ask-atlas` after several commits → shows staleness warning with commit count → loads docs → enters chat mode.

### Extra file context
`/ask-atlas --files src/auth/jwt.py "how is the JWT validated?"` → loads docs + reads `src/auth/jwt.py` → answers from both.

### Fresh regeneration
`/ask-atlas --fresh "what changed recently?"` → regenerates docs → answers from fresh docs.

### Follow-up questions
After entering chat mode, all subsequent messages in the conversation are answered from the already-loaded context — no re-reads, no re-checks.

---

## Notes

- **Do not scan source files.** The entire value of this command is answering from pre-built docs. Resist the urge to verify answers by grepping the codebase.
- **`--files` is the escape hatch.** When a question genuinely requires source-level detail, tell the user to re-invoke with `--files` pointing to the relevant file.
- **The staleness check uses the `detect-git-changes` skill** — the same skill used by `/codebase-overview`. It reads the last-updated date from `docs/codebase-index.json` or `docs/codebase-overview.md`.
- **If `docs/` does not exist**, the docs are missing — go directly to Step 3 auto-generation.
- **`--no-ml` only suppresses loading `docs/ml-overview.md`** — it does not affect what was in `docs/codebase-overview.md` (which may already summarise ML components).
