---
description: Analyse multiple repos (local paths or GitHub URLs) to map how they interact — dependency graph, cross-repo E2E flows, impact analysis, shared infrastructure, and data ownership — for any mix of backend, frontend, and ML services.
---

# Ecosystem Overview Generator

Analyse a set of related repositories and produce a unified picture of how they interact: who calls whom, what events flow between them, what breaks if something goes wrong, and how data moves end-to-end across the system.

Works with any combination of:
- Local repository checkouts
- GitHub URLs (public or private, if `gh` CLI is authenticated)
- A mix of both

---

## Purpose

Individual repo docs (`/codebase-overview`, `/ml-overview`) explain what a single service does. This skill answers the harder questions:
- How do these services fit together as a system?
- What is the E2E flow from a user action to a final outcome, traced across every repo it touches?
- If service X goes down or changes its API, what else breaks and how severely?
- Who owns what data? Who reads other services' data?
- Where are the single points of failure and tight coupling risks?

---

## Instructions

### Step 0 — Handle `--help`

If the user passes `--help` or `-h`, print the following and do nothing else:

```
/ecosystem-overview — Map how multiple repos interact across your system

USAGE
  /ecosystem-overview <repo1,repo2,...> [options]
  /ecosystem-overview --repos-file <path> [options]

DESCRIPTION
  Analyses a set of repos (local paths and/or GitHub URLs) and produces a unified
  view of how they interact: dependency graph, cross-repo E2E flows, impact analysis
  (blast radius), shared infrastructure, data ownership, and coupling assessment.

  Repos can be provided inline (comma-separated) or via a text file. GitHub repos
  are shallow-cloned using the gh CLI; local paths are read directly.

  If a repo cannot be accessed (private, missing path, auth failure), the run
  continues with the remaining repos and surfaces a clear error table at the top
  of the output. Partial analysis is always better than no analysis.

INPUT FILE FORMAT (--repos-file)
  # ecosystem-repos.txt
  # name: local-path-or-github-url
  service-a:   /Users/me/work/service-a
  service-b:   https://github.com/org/service-b
  ml-pipeline: /Users/me/work/ml-pipeline

OPTIONS
  --repos-file <path>    Path to repos .txt file (see format above)
  --output <dir>         Override output directory (default: docs/)
  --fresh                Ignore existing output files and regenerate from scratch
  --no-diagram           Skip .drawio and Mermaid files — overview doc only
  --with-excalidraw      Also generate docs/ecosystem.excalidraw
  --focus <area>         Extra depth on: impact | data | flows | contracts
  --help, -h             Show this help and exit

EXAMPLES
  /ecosystem-overview /path/to/svc-a,/path/to/svc-b
  /ecosystem-overview https://github.com/org/svc-a,https://github.com/org/svc-b
  /ecosystem-overview --repos-file /Users/me/work/my-system/repos.txt
  /ecosystem-overview --repos-file repos.txt --focus impact
  /ecosystem-overview --repos-file repos.txt --no-diagram --fresh

OUTPUT FILES (default)
  docs/ecosystem-overview.md      Main doc: dependency graph, flows, impact analysis
  docs/ecosystem.drawio           Editable diagram (swim lanes per repo)
  docs/ecosystem-diagram.md       Mermaid preview — renders in GitHub instantly
  docs/ecosystem.excalidraw       (only with --with-excalidraw)

REQUIRES (for GitHub URLs)
  gh CLI installed and authenticated. Run: gh auth login

RELATED SKILLS
  /codebase-overview    — Deep dive into a single repo before running ecosystem analysis
  /architecture-diagram — Diagram for a single repo
```

---

## Input File Format

When using `--repos-file`, the file must be a plain text file (`.txt`). Each non-comment line specifies one repo:

```
# ecosystem-repos.txt
# Format:  <display-name>: <local-path or GitHub URL>
# Lines starting with # are ignored. Blank lines are ignored.

roogo-service:      /Users/me/work/roogo-service
dispatcher:         https://github.com/deliveroo/dispatcher
partner-frontend:   /Users/me/work/partner-frontend
ml-demand-forecast: https://github.com/deliveroo/ml-demand-forecast
```

Rules:
- `<display-name>` is used as the label throughout the output docs. Keep it short and slug-friendly.
- `<local-path>` must be an absolute path to a directory that is a git repo.
- `<GitHub URL>` must be in the form `https://github.com/<owner>/<repo>` (no trailing slash, no `.git` suffix required but accepted).
- Order does not matter — dependency relationships are discovered, not assumed from order.

---

## Instructions

### Step 1 — Parse inputs

Determine which repos to analyse from the user's invocation:

**Inline repos** (passed directly on the command line, comma-separated):
- Parse each item: if it starts with `https://github.com/` treat as GitHub URL, otherwise treat as local path.
- Derive a display name from the repo/directory name.

**Repos file** (`--repos-file <path>`):
- Read the file at the given path.
- Parse each non-comment, non-blank line as `<name>: <path-or-url>`.
- If the file does not exist, stop immediately and output:
  ```
  ERROR: Repos file not found at <path>.
  Create the file with the format shown in the skill description and try again.
  ```

Build a list: `[ { name, source_type: "local"|"github", path_or_url } ]`

If the list is empty after parsing, stop and tell the user what was found.

### Step 2 — Access each repo

For each repo in the list, attempt to access it. Track results in a status table.

**Local repos:**
1. Check that the path exists and is a directory: `ls <path>`
2. Check it is a git repo: `git -C <path> rev-parse --git-dir`
3. If either check fails → mark as `FAILED` with reason, continue to next repo.
4. If it already has `docs/codebase-overview.md` or `docs/ml-overview.md` → note this — use these as fast-path inputs instead of re-exploring.

**GitHub repos:**
1. Check `gh` CLI is available: `gh --version`
   - If not available → mark ALL GitHub repos as `FAILED` with reason: "gh CLI not installed. Install from https://cli.github.com or use local paths instead."
2. Clone with shallow depth into a temp directory:
   ```bash
   gh repo clone <url> /tmp/ecosystem-overview/<name> -- --depth=1 --single-branch 2>&1
   ```
3. Handle clone failures explicitly:
   | Exit condition | Reason to report |
   |---------------|-----------------|
   | "Repository not found" | Repo does not exist or is private and you are not authenticated. Run `gh auth login` to authenticate. |
   | "authentication failed" | Run `gh auth login` and re-try. |
   | "rate limit" | GitHub API rate limit hit. Wait a few minutes or use a local clone. |
   | "already exists" | Temp dir already exists from a previous run — delete `/tmp/ecosystem-overview/<name>` and retry. |
   | Any other error | Paste the raw error message. |
4. On success → mark as `CLONED`, use `/tmp/ecosystem-overview/<name>` as the local path.

After processing all repos, if ANY repos failed:
- Do **not** stop. Continue with the repos that succeeded.
- At the very top of the output `docs/ecosystem-overview.md`, add a prominent warning block:

```markdown
> ⚠️ **Partial analysis** — the following repos could not be accessed and are excluded:
>
> | Repo | Reason |
> |------|--------|
> | `dispatcher` | Private repo — not authenticated. Run `gh auth login` to fix. |
> | `ml-demand-forecast` | Path `/Users/me/ml-demand-forecast` does not exist. |
>
> Re-run `/ecosystem-overview` after fixing these to get a complete picture.
```

If ALL repos failed, stop and output only the error table — do not create any docs.

### Step 3 — Extract per-repo interface profile

For each accessible repo, run an Explore subagent. Extract the **interface profile** — what the repo exposes and what it depends on. Do NOT produce a full codebase overview here (that is `/codebase-overview`'s job). Focus only on the cross-repo surface.

If `docs/codebase-overview.md` or `docs/ml-overview.md` already exists in the repo, read it first — it may answer most of these questions without deep exploration.

**What to extract:**

```
EXPOSES (outbound interface):
  REST/GraphQL/gRPC endpoints:
    - Method, path, brief purpose (e.g. POST /daas/v1/quotes — create price quote)
  Kafka / Pub-Sub topics PUBLISHED:
    - Topic name, message type/schema, what triggers publication
  SQS / event queues PUBLISHED:
    - Queue name, message type, trigger
  Webhooks sent to external parties:
    - Target type, payload shape, trigger
  Shared databases/stores accessible to others (if any):
    - Table/collection name, access pattern

DEPENDS ON (inbound dependencies):
  HTTP/gRPC calls TO other services:
    - Target service (name if known, URL/host if discoverable), endpoint, purpose
  Kafka / Pub-Sub topics CONSUMED:
    - Topic name, what it does with the messages
  SQS / event queues CONSUMED:
    - Queue name, processing logic summary
  Databases/stores READ from other services:
    - Table/bucket name, which service owns it

OWNS:
  Databases / data stores:
    - Name, type (DynamoDB, PostgreSQL, Redis, S3, etc.), what data lives there
  Message queues / topics:
    - Name, type

TECH PROFILE:
  Language + framework
  Deployment model (Lambda, ECS, K8s, Vercel, etc.)
  Auth mechanism (OAuth2, API key, mTLS, etc.)
```

### Step 4 — Build the dependency graph

From the interface profiles, resolve dependencies between repos in the analysis set.

**Matching strategy** (try in order):
1. **Exact URL match** — a repo's outbound HTTP call URL matches another repo's known host/domain.
2. **Topic name match** — a topic one repo publishes appears in another repo's consumed topics list.
3. **Queue name match** — same for queues.
4. **Endpoint path match** — a consumed endpoint path matches an exposed path on another repo.
5. **Named reference** — a repo's config or README explicitly names another service.

For each resolved dependency, record:
- Direction: `A → B`
- Mechanism: REST / gRPC / Kafka / SQS / DynamoDB stream / etc.
- Criticality: `SYNC` (request/response — caller blocks) or `ASYNC` (fire-and-forget / event)
- Brief label: what flows across (e.g. "POST /quotes", "deliveries topic", "webhook")

Unresolved dependencies (calls to services NOT in the analysis set) → record as `EXTERNAL: <host/topic>` nodes.

### Step 5 — Impact analysis

For each repo, derive:

**Blast radius (what breaks if THIS repo is down):**
- `SYNC` dependents: services that make blocking calls to this repo — they will start returning errors immediately.
- `ASYNC` dependents: services that consume events from this repo — they will stop receiving updates; may degrade gracefully depending on their retry/DLQ config.
- Transitive: if A → B → C and B is down, C is also affected.

**Dependency risk (what this repo needs to function):**
- `SYNC` dependencies: if any of these are down, this repo's affected endpoints will fail.
- `ASYNC` dependencies: if any of these are down, this repo stops receiving events — may accumulate lag.
- `SINGLE POINT OF FAILURE`: any dependency that has no fallback or retry logic visible in the code.

**Severity classification:**
- `P0` — sync dependency, no fallback, core path (e.g. auth service)
- `P1` — sync dependency with circuit breaker / fallback
- `P2` — async dependency, consumer has DLQ / retry
- `P3` — async dependency, best-effort, degraded but not broken

### Step 6 — Identify cross-repo E2E flows

Trace the most significant user/system journeys across the repos. A flow is cross-repo if it touches more than one repo in the analysis set.

For each flow:
1. Start from a user action or external trigger (API call, cron, event)
2. Follow sync and async hops across repos in sequence
3. Note where control is synchronous (caller waits) vs asynchronous (fire and forget, continued later)
4. Identify the terminal outcome (response to user, record in DB, event emitted, etc.)

Use this notation:
```
[Actor] → [Repo A]: mechanism — action
         → [Repo B]: mechanism — action  (async, continues after Repo A responds)
                   → [Repo C]: mechanism — action
         ← [Repo A]: response to actor
```

### Step 7 — Generate output files

#### 7a — `docs/ecosystem-overview.md`

Structure:

```markdown
<!-- Last updated: YYYY-MM-DD -->

# Ecosystem Overview

> **Repos analysed:** repo-a, repo-b, repo-c
> **Repos excluded (access failed):** repo-d (reason)
>
> Individual repo docs: [repo-a](../repo-a/docs/codebase-overview.md) · [repo-b](...)

---

## 1. Ecosystem at a Glance
Table: name | type | language | deployment | owns | exposes | depends on

## 2. Dependency Graph (ASCII)
Directed graph showing all repos and their connections.
Annotate each edge with mechanism (REST/Kafka/SQS/etc.) and SYNC/ASYNC.
Mark EXTERNAL nodes for out-of-scope dependencies.

## 3. Shared Infrastructure
Any databases, queues, or topics accessed by more than one repo.
Who is the owner? Who are the readers? Is there write contention?

## 4. API & Event Contract Map
For each cross-repo interface:
  - Producer repo → Consumer repo
  - Contract: endpoint/topic/queue + schema summary
  - Versioning: is there a version in the path/header/schema?

## 5. Cross-Repo E2E Flows
One sub-section per significant flow.
Include async continuations clearly marked.
Trace to file-level code paths where possible.

## 6. Impact Analysis
### 6a. Blast Radius Table
If repo X goes down → what breaks, severity (P0/P1/P2/P3), why.

### 6b. Single Points of Failure
Any repo that:
- Has no redundancy and is on the SYNC critical path of multiple others
- Has no circuit breaker / fallback visible in consuming code
- Owns a store that others write to with no eventual-consistency buffer

### 6c. Cascade Failure Scenarios
2-3 specific "what if…" scenarios tracing how an outage propagates.

## 7. Data Ownership Map
Who owns what data? Who reads whose data?
Flag any cases where two repos write to the same store (write contention risk).

## 8. Coupling & Cohesion Assessment
- Tightly coupled pairs (sync + shared DB)
- Good decoupling examples (async events, clear API contracts)
- Suggested improvements (non-prescriptive — note patterns that are known risks)

## 9. Per-Repo Interface Profiles
One sub-section per repo: exposes / depends on / owns — the raw extracted data from Step 3.
Link to full overview doc if it exists.

## 10. Excluded Repos & Next Steps
List any repos that failed to load with instructions to fix.
Suggest running /codebase-overview in each repo for deeper individual docs.
```

#### 7b — `docs/ecosystem.drawio`

Generate draw.io XML using the same conventions as the `architecture-diagram` skill.

Layout zones (top → bottom):
```
Row 0 (y=60):   Frontend / Client apps
Row 1 (y=200):  Public-facing APIs / Gateways
Row 2 (y=360):  Backend services / Workers
Row 3 (y=520):  ML services / pipelines
Row 4 (y=680):  Data stores / Queues / Topics
Row 5 (y=840):  External services (out of scope)
```

Node styles:
- Each repo = a **swim lane group** containing its owned resources
- REST edges: solid arrow, label = "REST"
- Kafka/event edges: dashed arrow, label = topic name
- SQS edges: dotted arrow, label = queue name
- EXTERNAL nodes: grey fill, dashed border

#### 7c — `docs/ecosystem-diagram.md`

Mermaid graph (renders in GitHub immediately) + instructions for opening the `.drawio` file.

Use `graph LR` for wide systems (many services in a row), `graph TD` for deep pipelines.

Use subgraphs to group repos by domain or team.

Annotate critical (P0/P1) edges in red using Mermaid `linkStyle`.

#### 7d — Merge behaviour

If any output file already exists:
- Read the existing file first.
- Preserve any manually added annotations or notes.
- Update sections where the extracted data has changed.
- Update the `Last updated` date.
- Flag any section where you are uncertain if existing content is still accurate with `<!-- verify -->`.

### Step 8 — Cleanup

Remove any temp directories created for GitHub clones:
```bash
rm -rf /tmp/ecosystem-overview/
```

---

## Parameters

- `<repo1,repo2,...>` — comma-separated list of local paths or GitHub URLs (inline, no flag needed)
- `--repos-file <path>` — path to a `.txt` file listing repos (see format above)
- `--output <dir>` — directory to write output files (default: `docs/`)
- `--fresh` — ignore existing output files and regenerate from scratch
- `--no-diagram` — skip generating `.drawio` and Mermaid files (overview doc only)
- `--with-excalidraw` — also generate `docs/ecosystem.excalidraw`
- `--focus <area>` — give extra depth to a specific concern: `impact`, `data`, `flows`, `contracts`

---

## Examples

### Example 1: Inline GitHub URLs
```
/ecosystem-overview https://github.com/org/service-a,https://github.com/org/service-b,https://github.com/org/service-c
```
Shallow-clone all three, analyse, produce ecosystem docs.

### Example 2: Local paths
```
/ecosystem-overview /Users/me/work/service-a,/Users/me/work/service-b
```
Read both local checkouts directly — no cloning needed.

### Example 3: Repos file (recommended for >3 repos)
```
/ecosystem-overview --repos-file /Users/me/work/my-system/ecosystem-repos.txt
```

### Example 4: Mix of local and remote
```
/ecosystem-overview --repos-file /Users/me/work/repos.txt
```
Where `repos.txt` contains some local paths and some GitHub URLs. Handles each appropriately.

### Example 5: Focus on impact analysis
```
/ecosystem-overview --repos-file repos.txt --focus impact
```
Produces the full doc but gives extra depth to blast radius, cascade failures, and SPOFs.

### Example 6: Docs only, no diagram
```
/ecosystem-overview --repos-file repos.txt --no-diagram
```

---

## Notes

- **Partial success is always better than total failure.** If 3 of 4 repos load, analyse the 3 and document the failure clearly. Do not abort the whole run.
- **Always explain WHY a repo failed**, not just that it did. "Private repo — not authenticated" is useful. "Error" is not.
- **Prefer existing docs over re-exploration.** If a repo already has `docs/codebase-overview.md`, use it as the primary source for that repo's interface profile. This is much faster and avoids redundant work.
- **SYNC vs ASYNC distinction is the most important thing to get right** in the dependency graph. A sync dependency that goes down takes its callers with it. An async dependency that goes down creates lag/backlog but callers may keep functioning. Always label edges with this.
- **Don't invent connections.** Only record dependencies that are explicitly visible in code, config, or docs. If a relationship seems likely but isn't confirmed, note it as `<!-- unconfirmed -->`.
- **Data ownership conflicts are high-risk.** If two repos write to the same store and neither has obvious coordination, flag it prominently in the impact analysis.
- **Temp dirs:** Always clean up `/tmp/ecosystem-overview/` at the end, even on failure.
- If `docs/` does not exist in the working directory, create it.
- Use GitHub-Flavored Markdown with ASCII diagrams. No external diagram dependencies.
- The `<!-- Last updated: YYYY-MM-DD -->` line must be the first line of every output file.