---
name: explore-repo-interface
description: Extract a repository's cross-repo interface profile — what it exposes, what it depends on, and what data it owns. Use when analysing multi-service systems, building ecosystem maps, understanding service dependencies, or determining a repo's blast radius in an outage.
allowed-tools: Read Glob Grep Bash
---

# Explore Repo Interface

Extract a repository's cross-repo interface profile: what it exposes to other services, what external services it depends on, what data it owns, and its tech stack. This profile is the building block for ecosystem-level dependency graphs and impact analysis.

## When to use this skill

- Called by `/ecosystem-overview` for each repo in the analysis set
- Use autonomously when you need to understand how a single repo fits into a larger system

---

## Output Format

Produce a structured profile for the repo:

```
REPO: <display-name>
PATH: <local path>

EXPOSES:
  REST/GraphQL/gRPC endpoints:
    - METHOD /path — brief purpose
  Kafka / Pub-Sub topics PUBLISHED:
    - topic-name (message type/schema) — what triggers publication
  SQS / event queues PUBLISHED:
    - queue-name — trigger
  Webhooks sent to external parties:
    - target type, payload shape, trigger
  Shared databases accessible to others (if any):
    - table/collection name, access pattern

DEPENDS ON:
  HTTP/gRPC calls TO other services:
    - Target: <service name or URL/host>, endpoint, purpose, SYNC/ASYNC
  Kafka / Pub-Sub topics CONSUMED:
    - topic-name — what it does with messages
  SQS / event queues CONSUMED:
    - queue-name — processing logic summary
  Databases READ from services not owned by this repo:
    - table/bucket name, owner service

OWNS:
  Databases / data stores:
    - name, type (DynamoDB/PostgreSQL/Redis/S3/etc.), what data lives there
  Message queues / topics:
    - name, type

TECH PROFILE:
  Language + framework
  Deployment model (Lambda / ECS / K8s / Vercel / etc.)
  Auth mechanism (OAuth2 / API key / mTLS / JWT / etc.)
```

---

## Instructions

### Step 1 — Fast path: check for existing index or overview

Check for `docs/codebase-index.json` at the repo root (or `<repo-path>/docs/codebase-index.json`).

**If index exists:** derive most of the profile directly:
- `EXPOSES` endpoints ← components with `type: "api"` and `layer: 1`; routes from handler files listed in `section_file_map["Component Map"]`
- `DEPENDS ON` ← components with `type: "external"` or `layer: 4`; deps that reference external names; `architecture.external_services`
- `OWNS` data stores ← `architecture.databases` and `architecture.queues`
- `TECH PROFILE` ← `architecture.languages`, `architecture.frameworks`, `architecture.deployment`

Only read source files when the index data is insufficient to determine a specific field. This path should take at most 2–3 targeted file reads.

**If `docs/codebase-overview.md` exists (but no index):** read it. It likely contains Component Map, Data Layer, and Architecture Patterns sections that answer most questions without code exploration.

**If neither exists:** proceed to deep exploration below.

### Step 2 — Deep exploration (no index, no overview)

Use an Explore subagent focused on the cross-repo surface only. Do NOT produce a full codebase overview — focus exclusively on what crosses repo boundaries.

**Find endpoints exposed:**
- Look for route registration files: `router.go`, `routes.py`, `app.ts`, `server.go`, `api.go`
- Look for handler files: `*_handler.go`, `*controller*`, `*handler*`
- Look for OpenAPI specs: `openapi.yml`, `swagger.yml`, `*.openapi.json`
- For gRPC: `*.proto` files and service definitions

**Find outbound HTTP/gRPC calls:**
- Look for HTTP client instantiation: `http.NewRequest`, `axios`, `fetch`, `requests.get`, `grpc.Dial`
- Look for client wrapper files: `*_client.go`, `clients/`, `integrations/`
- Config files often contain base URLs of external services

**Find Kafka/SQS topics:**
- For publishing: look for `Publish(`, `SendMessage(`, `producer.send(`, topic/queue name strings
- For consuming: look for `Subscribe(`, `ReceiveMessage(`, consumer group config, `@KafkaListener`
- Config files often list topic/queue names explicitly

**Find data stores owned:**
- Infrastructure files (`*.tf`, `serverless.yml`, `docker-compose.yml`): resource definitions reveal what this repo owns
- Database config/migration files: reveal table names and schema
- README or CLAUDE.md often lists owned infrastructure

**Find auth mechanism:**
- Middleware files: `auth.go`, `middleware/`, `auth/`
- Look for: JWT validation, OAuth2 token exchange, API key header checks, mTLS config

### Step 3 — Classify dependencies

For each dependency found, record:
- **SYNC** if the caller blocks waiting for a response (HTTP request, gRPC call)
- **ASYNC** if the caller does not wait (Kafka publish, SQS send, DynamoDB stream)

This SYNC/ASYNC distinction is the most important thing to get right. A SYNC dependency going down takes its callers down with it. An ASYNC dependency going down creates lag but callers may keep functioning.

### Step 4 — Return the profile

Output the structured profile in the format shown at the top. Keep it factual and structured — no prose. Use `<!-- unconfirmed -->` for any relationship that seems likely from context but isn't explicitly visible in code or config.

---

## Notes

- **Prefer existing docs over re-exploration.** An index or overview doc represents hours of prior analysis — use it.
- **SYNC vs ASYNC is the most important field.** If uncertain, investigate before guessing.
- **Only record what is explicitly visible in code, config, or docs.** Do not invent connections.
- **Scope is cross-repo surface only.** Do not document internal architecture — that's `/codebase-overview`'s job. Internal services that don't cross repo boundaries are out of scope here.
- **Config files are gold.** They often explicitly name external service URLs, topic names, queue ARNs, and database connection strings — read them early.
- **`<!-- unconfirmed -->`** is preferable to omission. A flagged uncertain relationship is more useful to the ecosystem analysis than a silently missing one.
