# Skill: Write Overview Doc

Read `docs/codebase-index.json` and produce `docs/codebase-overview.md` — the comprehensive human-readable architecture reference.

## When to use this skill

- Called by `codebase-overview` after the index has been built or updated
- Use autonomously when an index exists and you need to (re)generate the human-readable doc

---

## Prerequisites

`docs/codebase-index.json` must exist. If it does not, stop and report:

```
docs/codebase-index.json not found.
Run the index-codebase skill first (or run codebase-overview to do both in one step).
```

---

## Instructions

### Step 1 — Load the index

Read `docs/codebase-index.json`. This determines:
- Which files feed which sections (`section_file_map`)
- The component inventory, entities, ID types, and flows already extracted
- The language/framework profile

### Step 2 — Load existing overview (for merge)

If `docs/codebase-overview.md` already exists AND `--fresh` was NOT passed:
- Read it in full
- Parse the `<!-- Last updated: YYYY-MM-DD -->` date from line 1
- In targeted mode: sections **not** in `--sections` will be kept verbatim

If `--fresh` was passed: ignore any existing file and regenerate everything.

### Step 3 — Read source files per section

Use the index's `section_file_map` to know exactly which files to read for each section being generated. Read those files.

**Do not explore files not listed in the relevant section's `section_file_map` entry.** The index already determined what matters.

### Step 4 — Generate content

**Full mode** (`--fresh` or first run): produce all required sections.

**Targeted mode** (`--sections` provided): produce content **only for those sections**. Carry all other sections forward verbatim.

Always use concrete `file.go:FunctionName()` references.

### Step 5 — Merge (if existing file present)

| Situation | Action |
|---|---|
| Structurally changed | Replace with new content |
| Additive only | Merge new items in; keep existing accurate items |
| Unchanged | Keep existing wording |
| Uncertain | Keep it, append `<!-- verify -->` |

**Never silently delete existing nuances or gotchas.**

### Step 6 — Write the final file

The output file must begin with:

```
<!-- Last updated: YYYY-MM-DD -->
```

Then a cross-reference block linking to companion docs, followed by the full content.

---

## Required Sections

### 1. Repository Layout
Annotated directory tree from the index's `files[]` and directory structure.

### 2. Component Map
Table of every significant component with purpose and entry point.

### 3. Domain Models Deep Dive
Field-level breakdown of core entities: key fields, status enums, lifecycle, constraints.

### 4. ID / Key System
Comparison table of every identifier type. **Most valuable section for new engineers.**

### 5. E2E Flows with Code Paths
Every significant journey traced with `file.go:Fn()` references, including async continuations.

### 6. Architecture Patterns
Recurring patterns: event-driven, CQRS, optimistic locking, circuit breaker, etc.

### 7. Data Layer
Tables/collections, indexes, consistency model, caching, and access patterns.

### 8. Tricky Parts & Nuances
Non-obvious behaviours. Aim for **8–15 items**. Always explain the *why*.

### 9. State Machine Reference
Status/state transition diagrams for key entities. Use ASCII diagrams.

### 10. Testing Approach
Unit vs integration vs E2E, how to run each, special patterns.

### 11. Key File Quick Reference
Table of the most important files with single-line purpose.

---

## Parameters

- `--output <path>`: Override output path
- `--fresh`: Ignore existing file, regenerate all sections
- `--sections <section1,section2,...>`: Only regenerate these sections (targeted mode)
- `--focus <area>`: Give extra depth to one area

---

## Notes

- **The ID/Key System section is the highest-value section for new engineers.**
- **E2E flows must include async continuations.**
- **Tricky Parts should explain the *why*.**
- **The document should serve two audiences**: someone who has never seen the codebase AND someone debugging a production incident at 2 AM.
