# Skill: Detect Git Changes

Determine what changed in the repo since the last `docs/codebase-overview.md` update and produce a structured result that tells the caller exactly what to re-index and which doc sections to regenerate.

## When to use this skill

- Called by `codebase-overview` at the start of a refresh run (not `--fresh`)
- Called by `ask-atlas` to check doc staleness
- Use autonomously when you need to know what has changed in a codebase since a given date

---

## Output

This skill produces a structured result (used by the calling command):

```
mode:             "current" | "targeted" | "full"
changed_files:    [list of file paths]  — empty if mode=current
affected_sections:[list of section names] — empty if mode=current or mode=full
commit_messages:  [list of commit subject lines]
reason:           human-readable explanation of why this mode was chosen
```

- **`current`**: no commits since last update — doc is up to date, refresh date only
- **`targeted`**: ≤20 files changed across ≤5 packages — only re-index and rewrite affected sections
- **`full`**: too many changes, hub files changed, or git unavailable — full re-index required

---

## Instructions

### Step 1 — Extract last-updated date

**Prefer the index** (`docs/codebase-index.json`): read `meta.generated_at`.

**Fallback to the overview doc** (`docs/codebase-overview.md`): parse the `<!-- Last updated: YYYY-MM-DD -->` line from line 1.

If neither source yields a parseable date → output `mode: "full"` with `reason: "Could not determine last-updated date — falling back to full exploration"`. Stop here.

### Step 2 — Get commits since that date

```bash
git log --since="LAST_UPDATED_DATE" --oneline
```

Handle each outcome:

| Outcome | Result |
|---------|--------|
| `git` not available | `mode: "full"`, reason: "git not available" |
| Not a git repo | `mode: "full"`, reason: "not a git repo" |
| Command fails for any other reason | `mode: "full"`, reason: log the raw error |
| Zero commits returned | `mode: "current"`, reason: "No commits since LAST_UPDATED_DATE" |
| One or more commits | Continue to Step 3 |

### Step 3 — Get changed files and commit messages

```bash
git log --since="LAST_UPDATED_DATE" --name-only --pretty=format:""
```

Deduplicate file paths, strip blank lines → `changed_files`.

```bash
git log --since="LAST_UPDATED_DATE" --pretty=format:"%s"
```

Collect → `commit_messages`.

### Step 4 — Decide mode

Count distinct **packages** changed (unique parent directories of changed files).

| Condition | Mode |
|-----------|------|
| Any hub file changed — `go.mod`, `package.json`, `requirements.txt`, the primary domain model file, `main.go`, `main.py`, `index.ts` for the web service | `full` — hub changes cascade everywhere |
| >20 files changed | `full` — too broad for targeted refresh |
| >5 distinct packages changed | `full` — cross-cutting change |
| ≤20 files AND ≤5 packages AND no hub files | `targeted` |

### Step 5 — Map changed files to affected sections

**Only in targeted mode.**

**Priority: use the index** (`docs/codebase-index.json`): for each file in `changed_files`, look it up in the index's `files[]` array and read its `feeds_sections`. Collect the union of all feeds_sections → `affected_sections`.

**Fallback: heuristic pattern table** (when no index exists):

| Changed file pattern | Sections affected |
|---|---|
| `internal/domain/*.go`, `domain/`, `models/`, `entities/` | `Domain Models`, `State Machine Reference`, `ID / Key System` |
| `internal/rest/*.go`, `handlers/`, `routes/`, `controllers/`, `openapi/*.yml` | `E2E Flows`, `Component Map`, `Key File Quick Reference` |
| `internal/**/repo.go`, `*repository*.go`, `*_store.go`, db config | `Data Layer`, `E2E Flows` |
| `cmd/lambdas/**`, `functions/`, `lambdas/` | `Component Map`, `Repository Layout`, `E2E Flows` |
| `internal/service/**`, `services/`, `usecases/` | `E2E Flows`, `Architecture Patterns` |
| `internal/config/**`, `config.go`, `*.env*` | `Data Layer`, `Architecture Patterns` |
| `cmd/services/**`, `cmd/workers/**` | `Component Map`, `Repository Layout` |
| New top-level directories | `Repository Layout`, `Component Map` |
| `*_test.go`, `*_test.py`, `*.test.ts`, `*.spec.ts` | `Testing Approach` |

---

## Notes

- **The index's `feeds_sections` per file is always preferred over heuristic patterns.**
- **Log the mode and reason clearly** so the calling command can surface it to the user.
- **When in doubt, use `full` mode.**
- **Commit messages provide intent** — use them to sanity-check section mapping.
