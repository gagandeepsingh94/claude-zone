---
name: write-overview-doc
description: Read docs/codebase-index.json and write docs/codebase-overview.md — a comprehensive human-readable architecture reference. Use after indexing a codebase to generate or refresh documentation covering repository layout, component map, domain models, E2E flows, data layer, and tricky nuances.
allowed-tools: Read Write Edit
---

# Write Overview Doc

Read `docs/codebase-index.json` and produce `docs/codebase-overview.md` — the comprehensive human-readable architecture reference that gives any engineer an immediate bird's-eye view of the service.

## When to use this skill

- Called by `/codebase-overview` after the index has been built or updated
- Use autonomously when an index exists and you need to (re)generate the human-readable doc

---

## Prerequisites

`docs/codebase-index.json` must exist. If it does not, stop and report:

```
docs/codebase-index.json not found.
Run the index-codebase skill first (or run /codebase-overview to do both in one step).
```

---

## Instructions

### Step 1 — Load the index

Read `docs/codebase-index.json`. This determines:
- Which files feed which sections (`section_file_map`)
- The component inventory, entities, ID types, and flows already extracted
- Whether this is a Go / Python / TS / etc. codebase

### Step 2 — Load existing overview (for merge)

If `docs/codebase-overview.md` already exists AND `--fresh` was NOT passed:
- Read it in full
- Parse the `<!-- Last updated: YYYY-MM-DD -->` date from line 1
- In targeted mode: sections **not** in `--sections` will be kept verbatim

If `--fresh` was passed: ignore any existing file and regenerate everything.

### Step 3 — Read source files per section

Use the index's `section_file_map` to know exactly which files to read for each section being generated. Read those files using the Read tool.

**Do not explore files not listed in the relevant section's `section_file_map` entry.** The index already determined what matters.

For sections whose `section_file_map` entry is empty (e.g. `Repository Layout`, `Tricky Parts`, `Key File Quick Reference`): derive content from the full index structure itself — component list, file list, architecture field, entities, flows.

### Step 4 — Generate content

**Full mode** (`--fresh` or first run): produce all required sections (see below).

**Targeted mode** (`--sections` provided): produce content **only for those sections**. For all other sections, carry forward the existing text verbatim — do not regenerate, do not mark with `<!-- verify -->` unless you have a specific reason to doubt accuracy.

Always use concrete `file.go:FunctionName()` references. Engineers must be able to navigate directly to the code from this doc.

### Step 5 — Merge (if existing file present)

**Do NOT blindly overwrite.** Apply per-section merge rules:

| Situation | Action |
|---|---|
| Structurally changed (new component, renamed file, removed flow) | Replace with new content |
| Additive only (new nuance, new flow step, new tricky part) | Merge new items in; keep existing items that are still accurate |
| Unchanged (same files, same behaviour) | Keep existing wording (it may be more polished) |
| Uncertain whether existing note is still accurate | Keep it, append `<!-- verify -->` |

**Never silently delete existing nuances or gotchas** — they were written for a reason.

### Step 6 — Write the final file

The output file must begin with:

```
<!-- Last updated: YYYY-MM-DD -->
```

(Use today's date.)

Then a cross-reference block linking to companion docs (`docs/codebase-index.json`, `docs/architecture-diagram.md` if it exists, `docs/ml-overview.md` if it exists), followed by the full content.

If `docs/` does not exist, create it.

---

## Required Sections

Adapt headings to the service name but always include all of these:

### 1. Repository Layout

Annotated directory tree. Derive from the index's `files[]` and directory structure. Show what each top-level folder and key subdirectory contains in one line.

### 2. Component Map

Table of every significant component with its purpose and entry point. Derive from `components[]` in the index.

| Component | Type | Purpose | Entry Point |
|---|---|---|---|

### 3. Domain Models Deep Dive

Field-level breakdown of core entities: key fields, status enums, lifecycle, constraints. Derive from `entities[]` and by reading the domain model files listed in `section_file_map["Domain Models"]`.

Always include the full list of states and what each state means behaviourally.

### 4. ID / Key System

Comparison table of every identifier type. This is the **most valuable section for new engineers**; invest extra effort here.

| ID Type | Format | Who Creates It | Where Used |
|---|---|---|---|

Derive from `id_types[]` in the index. Read the relevant files to add context.

### 5. E2E Flows with Code Paths

Every significant journey traced with `file.go:Fn()` references, including async continuations. Derive from `flows[]` and by reading the handler/service files listed in `section_file_map["E2E Flows"]`.

Format each flow as a numbered trace:
```
1. Partner → POST /v1/deliveries
2. handler.go:CreateDelivery → validates input
3. service.go:Create → applies business rules
4. repo.go:Put → writes to DynamoDB
5. HTTP 201 returned to partner
6. (async) DynamoDB stream → lambda.go:ProcessNew → publishes event
```

**Always trace async continuations.** "HTTP 201 returned immediately; async pipeline continues via DynamoDB stream → …"

### 6. Architecture Patterns

Recurring patterns in the codebase: event-driven, CQRS, optimistic locking, circuit breaker, at-least-once delivery, saga, etc. Derive from the index `architecture` field and by reading the service/config files listed in `section_file_map["Architecture Patterns"]`.

For each pattern: name it, explain why it's used here, and reference the file where it's applied.

### 7. Data Layer

Tables/collections, indexes, consistency model, caching, and data access patterns. Derive from `architecture.databases`, `architecture.queues`, and files in `section_file_map["Data Layer"]`.

Include: table names, key schema (partition key / sort key for DynamoDB, primary key / indexes for SQL), and access patterns.

### 8. Tricky Parts & Nuances

Non-obvious behaviours and design decisions. Aim for **8–15 items**. Always explain the *why*, not just the *what*.

Examples of things worth capturing:
- Ordering guarantees (or lack of them) in async pipelines
- Idempotency requirements and how they're enforced
- Race conditions and how they're mitigated
- Counter-intuitive field meanings or status transitions
- At-least-once delivery implications
- Configuration values that must match across services
- Hidden coupling between components

Derive by reading all significant files in the index and reasoning about what would bite a new engineer.

### 9. State Machine Reference

Status/state transition diagrams for key entities. Use ASCII diagrams.

```
pending → in_progress → completed
       ↘              ↗
        cancelled
```

For each entity with states: list all valid transitions and what triggers each one. Derive from `entities[].states` and domain model files.

### 10. Testing Approach

Unit vs integration vs E2E, how to run each, and special patterns (test doubles, in-memory fakes, seeded fixtures). Derive from test files in `section_file_map["Testing Approach"]`.

Include: how to run the test suite, what is mocked vs real, any notable test patterns.

### 11. Key File Quick Reference

Table of the most important files with single-line purpose. Derive from the index `files[]` ordered by relevance (handlers, services, domain models first).

| File | Purpose |
|---|---|

---

## Parameters

- `--output <path>`: Override output path (default: `docs/codebase-overview.md`)
- `--fresh`: Ignore existing file, regenerate all sections from scratch
- `--sections <section1,section2,...>`: Only regenerate these sections; carry forward all others verbatim (targeted mode)
- `--focus <area>`: Give extra depth to one area (e.g. `"async pipeline"`, `"data layer"`)

---

## Notes

- **The ID/Key System section is the highest-value section for new engineers.** It is also where subtle bugs hide. Read the relevant files carefully even in targeted mode if IDs changed.
- **E2E flows must include async continuations.** A flow that says "returns HTTP 201" and stops is incomplete — trace what happens asynchronously after that.
- **Tricky Parts should explain the *why*.** "The delivery_id is set by the API, not the database, because the ID is used as a DynamoDB partition key before the item is written" is useful. "The ID is set in the handler" is not.
- **Use GitHub-Flavored Markdown with ASCII diagrams** — no external diagram dependencies.
- **The document should serve two audiences**: someone who has never seen the codebase AND someone debugging a production incident at 2 AM.
- In targeted mode: do NOT regenerate sections not in `--sections`. Carrying them forward verbatim is correct and intentional.
