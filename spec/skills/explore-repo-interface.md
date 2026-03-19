# Skill: Explore Repo Interface

Extract a repository's cross-repo interface profile: what it exposes to other services, what external services it depends on, what data it owns, and its tech stack.

## When to use this skill

- Called by `ecosystem-overview` for each repo in the analysis set
- Use autonomously when you need to understand how a single repo fits into a larger system

---

## Output Format

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

OWNS:
  Databases / data stores:
    - name, type, what data lives there
  Message queues / topics:
    - name, type

TECH PROFILE:
  Language + framework
  Deployment model
  Auth mechanism
```

---

## Instructions

### Step 1 — Fast path: check for existing index or overview

**If `docs/codebase-index.json` exists:** derive the profile directly from it. Only read source files when the index data is insufficient. This should take at most 2–3 targeted file reads.

**If `docs/codebase-overview.md` exists (but no index):** read it. It likely contains Component Map, Data Layer, and Architecture Patterns sections that answer most questions.

**If neither exists:** proceed to deep exploration below.

### Step 2 — Deep exploration (no index, no overview)

Focus exclusively on what crosses repo boundaries — do NOT produce a full codebase overview.

**Find endpoints exposed:**
- Route registration files: `router.go`, `routes.py`, `app.ts`, `server.go`
- Handler files: `*_handler.go`, `*controller*`
- OpenAPI specs: `openapi.yml`, `swagger.yml`
- For gRPC: `*.proto` files

**Find outbound HTTP/gRPC calls:**
- HTTP client instantiation: `http.NewRequest`, `axios`, `fetch`, `requests.get`, `grpc.Dial`
- Client wrapper files: `*_client.go`, `clients/`, `integrations/`
- Config files with base URLs

**Find Kafka/SQS topics:**
- Publishing: `Publish(`, `SendMessage(`, `producer.send(`
- Consuming: `Subscribe(`, `ReceiveMessage(`, consumer group config

**Find data stores owned:**
- Infrastructure files: `*.tf`, `serverless.yml`, `docker-compose.yml`
- Database config/migration files

**Find auth mechanism:**
- Middleware files: `auth.go`, `middleware/`, `auth/`

### Step 3 — Classify dependencies

For each dependency, record:
- **SYNC** if the caller blocks waiting for a response
- **ASYNC** if the caller does not wait

### Step 4 — Return the profile

Output the structured profile in the format shown above. Use `<!-- unconfirmed -->` for any relationship that seems likely from context but isn't explicitly visible.

---

## Notes

- **Prefer existing docs over re-exploration.**
- **SYNC vs ASYNC is the most important field.**
- **Only record what is explicitly visible in code, config, or docs.**
- **Scope is cross-repo surface only.** Internal architecture is out of scope here.
- **Config files are gold.** They often explicitly name external service URLs, topic names, and queue ARNs.
