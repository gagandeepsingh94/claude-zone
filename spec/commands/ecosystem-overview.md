# Command: Ecosystem Overview

Orchestrates cross-repo analysis across a set of related repositories: extracting interface profiles, building a dependency graph, running impact analysis, and producing ecosystem documentation and diagrams.

## Skills used

| Step | Skill | Purpose |
|------|-------|---------|
| 3 | `explore-repo-interface` | Extract each repo's interface profile (per repo, in parallel where possible) |
| 7 | `generate-diagram` | Produce ecosystem draw.io / Mermaid diagram files |

---

## Step 0 — Handle `--help`

If the user passes `--help` or `-h`, print the following and do nothing else:

```
ecosystem-overview — Map how multiple repos interact across your system

USAGE
  ecosystem-overview <repo1,repo2,...> [options]
  ecosystem-overview --repos-file <path> [options]

DESCRIPTION
  Analyses a set of repos (local paths and/or GitHub URLs) and produces:
    docs/ecosystem-overview.md   Dependency graph, flows, impact analysis
    docs/ecosystem.drawio        Editable diagram (swim lanes per repo)
    docs/ecosystem-diagram.md    Mermaid preview

  For each repo, the explore-repo-interface skill is used to extract what
  the repo exposes, what it depends on, and what data it owns.
  If a repo already has docs/codebase-index.json, that fast-path is used
  automatically — no re-exploration needed.

INPUT FILE FORMAT (--repos-file)
  # ecosystem-repos.txt
  # name: local-path-or-github-url
  service-a:   /Users/me/work/service-a
  service-b:   https://github.com/org/service-b

OPTIONS
  --repos-file <path>    Path to repos .txt file
  --output <dir>         Override output directory (default: docs/)
  --fresh                Ignore existing output files and regenerate from scratch
  --no-diagram           Skip diagram files — overview doc only
  --with-excalidraw      Also generate docs/ecosystem.excalidraw
  --focus <area>         Extra depth on: impact | data | flows | contracts
  --help, -h             Show this help and exit

OUTPUT FILES
  docs/ecosystem-overview.md
  docs/ecosystem.drawio          (unless --no-diagram)
  docs/ecosystem-diagram.md      (unless --no-diagram)
  docs/ecosystem.excalidraw      (only with --with-excalidraw)

REQUIRES (for GitHub URLs)
  gh CLI installed and authenticated: gh auth login

RELATED SKILLS
  codebase-overview    — Deep dive into a single repo before running ecosystem analysis
  architecture-diagram — Diagram for a single repo
```

---

## Step 1 — Parse inputs

**Inline repos** (comma-separated on the command line):
- Items starting with `https://github.com/` → GitHub URL
- Others → local path
- Derive display name from repo/directory name

**Repos file** (`--repos-file <path>`):
- Read the file. Parse each non-comment, non-blank line as `<name>: <path-or-url>`.
- If file not found: stop with a clear error message.

Build list: `[{ name, source_type: "local"|"github", path_or_url }]`

If the list is empty: stop and tell the user what was found.

---

## Step 2 — Access each repo

**Local repos:**
1. Verify path exists and is a git repo: `git -C <path> rev-parse --git-dir`
2. On failure → mark `FAILED` with reason, continue with remaining repos

**GitHub repos:**
1. Check `gh` CLI: `gh --version` — if missing, mark all GitHub repos FAILED
2. Shallow-clone: `gh repo clone <url> /tmp/ecosystem-overview/<name> -- --depth=1 --single-branch`
3. On clone failure → mark `FAILED` with specific reason (not found / auth / rate limit / etc.)

**After processing all repos:**
- If ANY failed: add a prominent warning block at the top of the output doc listing each failure and how to fix it. Continue with successful repos.
- If ALL failed: stop. Output only the error table.

---

## Step 3 — Run `explore-repo-interface` skill per repo

Follow the instructions in `spec/skills/explore-repo-interface.md` for each accessible repo.

Run in parallel where possible (multiple repos can be explored concurrently as they are independent).

The skill:
- Fast-paths via `docs/codebase-index.json` if it exists in the repo
- Falls back to `docs/codebase-overview.md` if available
- Falls back to direct exploration if neither exists

Collect a structured interface profile for each repo.

---

## Step 4 — Build the dependency graph

From the collected interface profiles, resolve dependencies between repos in the analysis set.

**Matching strategy** (try in order):
1. Exact URL match — outbound HTTP call URL matches another repo's known host
2. Topic name match — a published topic matches another repo's consumed topics
3. Queue name match — same for queues
4. Endpoint path match — a consumed endpoint path matches an exposed path
5. Named reference — config or README explicitly names another service

For each resolved dependency, record:
- Direction: `A → B`
- Mechanism: REST / gRPC / Kafka / SQS / DynamoDB stream / etc.
- Criticality: `SYNC` (caller blocks) or `ASYNC` (fire-and-forget / event)
- Label: brief description of what flows

Unresolved dependencies (calls to services NOT in the analysis set) → record as `EXTERNAL: <host/topic>` nodes.

---

## Step 5 — Impact analysis

For each repo, derive:

**Blast radius** (what breaks if this repo is down):
- SYNC dependents: services that make blocking calls here — fail immediately
- ASYNC dependents: services that consume events here — stop receiving updates
- Transitive: A → B → C means C is also affected if B is down

**Dependency risk** (what this repo needs):
- SYNC dependencies: if any are down, this repo's affected endpoints fail
- ASYNC dependencies: if down, this repo accumulates consumer lag

**Severity classification:**
- `P0` — sync dependency, no fallback, on core path
- `P1` — sync dependency with circuit breaker / fallback
- `P2` — async dependency, consumer has DLQ / retry
- `P3` — async dependency, best-effort

---

## Step 6 — Identify cross-repo E2E flows

Trace the most significant user/system journeys that cross ≥2 repos. For each flow:
1. Start from a user action or external trigger
2. Follow sync and async hops across repos in sequence
3. Note where control is SYNC vs ASYNC
4. Identify the terminal outcome

---

## Step 7 — Write `docs/ecosystem-overview.md`

Structure:

```
<!-- Last updated: YYYY-MM-DD -->

# Ecosystem Overview

> Repos analysed: ...
> Repos excluded: ... (with reasons)
> Diagrams: ecosystem-diagram.md · ecosystem.drawio

---

## 1. Ecosystem at a Glance
## 2. Dependency Graph (ASCII)
## 3. Shared Infrastructure
## 4. API & Event Contract Map
## 5. Cross-Repo E2E Flows
## 6. Impact Analysis
## 7. Data Ownership Map
## 8. Coupling & Cohesion Assessment
## 9. Per-Repo Interface Profiles (Raw Data)
## 10. Excluded Repos & Next Steps
```

Merge rules if the file already exists:
- Preserve manually added annotations
- Update sections where extracted data changed
- Add `<!-- verify -->` where uncertain
- Update `Last updated` date

---

## Step 8 — Run the `generate-diagram` skill *(unless `--no-diagram` was passed)*

Follow the instructions in `spec/skills/generate-diagram.md`.

For ecosystem diagrams, use these conventions:
- Each repo = a swim lane group
- Layout: `Row 0` = frontend/actors, `Row 1` = public APIs, `Row 2` = backend services/workers/lambdas, `Row 3` = data stores/queues, `Row 4` = external services
- REST edges: solid arrow; Kafka/event edges: dashed arrow; SQS edges: dotted arrow
- EXTERNAL nodes: grey fill, dashed border

For the Mermaid preview, produce **two diagrams** in `docs/ecosystem-diagram.md`:
1. **Full Component Diagram** (`graph LR`) — every component as its own node
2. **Critical Path Summary** (`graph LR`) — one node per repo, P0/P1 edges highlighted in red

If `--with-excalidraw` was passed: also generate `docs/ecosystem.excalidraw`.

---

## Step 9 — Cleanup

Remove temp directories created for GitHub clones:
```bash
rm -rf /tmp/ecosystem-overview/
```

---

## Notes

- **Partial success is always better than total failure.** If 3 of 4 repos load, analyse the 3 and document the failure.
- **Prefer existing docs over re-exploration.** If a repo has `docs/codebase-index.json`, the explore-repo-interface skill will use it automatically.
- **SYNC vs ASYNC is the most important field to get right.**
- **Never abbreviate components in diagrams.**
- **Don't invent connections.** Only record dependencies explicitly visible in code, config, or docs.
- The `<!-- Last updated: YYYY-MM-DD -->` line must be the first line of every output file.
- If `docs/` does not exist, create it.
