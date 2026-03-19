---
name: index-codebase
description: Build or update docs/codebase-index.json — a structured machine-readable map of a codebase. Use when you need to index a codebase, build a component inventory, extract domain models or E2E flows, enable targeted doc refresh, or power architecture diagram generation.
allowed-tools: Read Glob Grep Bash Write
---

# Index Codebase

Build or update `docs/codebase-index.json` — a structured map of the codebase. This index is the shared source of truth used by the `write-overview-doc`, `detect-git-changes`, `generate-diagram`, and `explore-repo-interface` skills.

## When to use this skill

- Called by `/codebase-overview` before writing the overview doc
- Called by `/architecture-diagram` when no index exists yet
- Use autonomously whenever you need a structured, queryable map of a codebase

---

## Index Schema

`docs/codebase-index.json` structure:

```json
{
  "meta": {
    "schema_version": "1",
    "generated_at": "YYYY-MM-DD",
    "git_sha": "abc123",
    "repo_name": "derived from root directory name"
  },
  "files": [
    {
      "path": "internal/domain/delivery.go",
      "component_type": "domain_model",
      "symbols": ["Delivery", "DeliveryStatus", "StatusPending", "StatusCompleted"],
      "feeds_sections": ["Domain Models", "State Machine Reference", "ID / Key System"],
      "last_modified_sha": "def456"
    }
  ],
  "components": [
    {
      "id": "delivery-api",
      "name": "Delivery API",
      "type": "api",
      "layer": 1,
      "files": ["internal/rest/handler.go", "internal/rest/router.go"],
      "deps": ["delivery-service", "dynamo-deliveries"]
    }
  ],
  "entities": [
    {
      "name": "Delivery",
      "file": "internal/domain/delivery.go",
      "id_field": "delivery_id",
      "states": ["pending", "in_progress", "completed", "cancelled"]
    }
  ],
  "id_types": [
    {
      "name": "delivery_id",
      "format": "UUID v4",
      "creator": "Delivery API on POST /deliveries",
      "used_in": ["deliveries table", "pickup service", "partner webhook"]
    }
  ],
  "flows": [
    {
      "name": "Create Delivery",
      "entry": "internal/rest/handler.go:CreateDelivery",
      "steps": [
        "internal/service/delivery.go:Create",
        "internal/repo/delivery_repo.go:Put",
        "internal/events/publisher.go:Publish"
      ]
    }
  ],
  "section_file_map": {
    "Repository Layout": [],
    "Component Map": ["cmd/", "internal/service/", "internal/rest/"],
    "Domain Models": ["internal/domain/delivery.go", "internal/domain/pickup.go"],
    "ID / Key System": ["internal/domain/delivery.go"],
    "E2E Flows": ["internal/rest/handler.go", "internal/service/delivery.go"],
    "Architecture Patterns": ["go.mod"],
    "Data Layer": ["internal/repo/delivery_repo.go", "internal/config/dynamodb.go"],
    "Tricky Parts": [],
    "State Machine Reference": ["internal/domain/delivery.go"],
    "Testing Approach": ["internal/service/delivery_test.go"],
    "Key File Quick Reference": []
  },
  "architecture": {
    "languages": ["Go"],
    "frameworks": ["gin", "aws-sdk-go-v2"],
    "deployment": ["lambda", "ecs"],
    "databases": [{ "type": "dynamodb", "tables": ["deliveries", "pickups"] }],
    "queues": [{ "type": "sqs", "names": ["delivery-events-queue"] }],
    "external_services": ["stripe", "twilio"]
  }
}
```

---

## Enum Reference

### `component_type` values

| Value | When to use |
|-------|-------------|
| `domain_model` | Core entity / struct / enum defining the domain |
| `handler` | HTTP handler, route, controller |
| `service` | Business logic layer |
| `repo` | Data access / repository layer |
| `lambda` | Serverless function entry point |
| `consumer` | Message queue / event consumer |
| `worker` | Background worker / cron job |
| `config` | Configuration / environment setup |
| `infra` | Infrastructure definitions (Terraform, CDK, k8s YAML) |
| `test` | Test file — do not deep-index |
| `other` | Does not fit above categories |

### `component.layer` values (used for diagram layout)

| Value | Meaning |
|-------|---------|
| `0` | Actor / external client |
| `1` | API / gateway / public-facing entry point |
| `2` | Internal service / worker / lambda / consumer |
| `3` | Data store / message queue / cache |
| `4` | External third-party service |

### `feeds_sections` allowed values

Use only these exact strings (they match overview doc section headings):

- `"Repository Layout"`
- `"Component Map"`
- `"Domain Models"`
- `"ID / Key System"`
- `"E2E Flows"`
- `"Architecture Patterns"`
- `"Data Layer"`
- `"Tricky Parts"`
- `"State Machine Reference"`
- `"Testing Approach"`
- `"Key File Quick Reference"`

---

## File → Section Mapping Table

Use this to assign `feeds_sections` to each file during indexing:

| File pattern | `feeds_sections` to assign |
|---|---|
| Domain entity / struct / status enum | `Domain Models`, `State Machine Reference`, `ID / Key System` |
| HTTP handler / route / controller | `E2E Flows`, `Component Map`, `Key File Quick Reference` |
| Service / business logic | `E2E Flows`, `Architecture Patterns` |
| Repository / data access layer | `Data Layer`, `E2E Flows` |
| Lambda / serverless entry point | `Component Map`, `Repository Layout`, `E2E Flows` |
| Consumer / async worker entry point | `Component Map`, `Repository Layout`, `E2E Flows` |
| Configuration / env setup | `Data Layer`, `Architecture Patterns` |
| Dependency manifest (`go.mod`, `package.json`, `requirements.txt`) | `Architecture Patterns` |
| Infrastructure files (`*.tf`, `*.cdk.ts`, `docker-compose.yml`, `k8s/`) | `Architecture Patterns`, `Repository Layout` |
| Test files | `Testing Approach` |
| Top-level directory (inferred from structure) | `Repository Layout`, `Component Map` |

When uncertain, assign `Key File Quick Reference` plus the most relevant section.

---

## Instructions

### Mode A — Full index (first run or `--fresh`)

**1. Get current git SHA**

```bash
git rev-parse HEAD
```

Record in `meta.git_sha`. If not a git repo, use `null`.

**2. Discover all significant files**

Use Glob to find source files. Skip:
- `vendor/`, `node_modules/`, `.git/`, `dist/`, `build/`, `.cache/`
- Generated files: `*_generated.go`, `*.pb.go`, `mock_*.go`, `__pycache__/`
- Binary artefacts: `*.so`, `*.dylib`, `*.exe`, `*.wasm`

Group by type: source files (`*.go`, `*.py`, `*.ts`, `*.js`, `*.java`, `*.rs`), config (`*.yaml`, `*.yml`, `*.toml`), infra (`*.tf`, `docker-compose.yml`, `k8s/`).

**3. Classify each file**

For every significant file (not tests, not generated):

- **`component_type`**: infer from path and content. Examples: `*_repo.go` or `*repository.go` → `repo`; `cmd/lambdas/*` → `lambda`; files exporting entity structs with status enums → `domain_model`; `*_handler.go` or `routes.go` → `handler`.

- **`symbols`**: Read the file using the Read tool. Extract all exported names:
  - Go: `type Foo struct`, `type Foo interface`, `func (r *T) Foo(`, `func Foo(`
  - Python: `class Foo`, `def foo` (public)
  - TypeScript/JS: `export const`, `export function`, `export class`, `export interface`

- **`feeds_sections`**: apply the File → Section Mapping Table above.

- **`last_modified_sha`**: `git log -1 --format="%H" -- <filepath>`. Use `null` if not in git.

**4. Build components**

Group files into logical deployable/logical units. A component is things like: "the REST API server", "the delivery-events consumer lambda", "the DynamoDB deliveries table". Each component:
- `id`: URL-slug of the name (e.g. `delivery-api`, `dynamo-deliveries`)
- `name`: human-readable
- `type`: api | service | worker | lambda | consumer | cron | data_store | queue | external
- `layer`: 0–4 per the enum above
- `files`: list of file paths that implement this component
- `deps`: list of other component IDs this component calls/uses (derive from imports and config)

**5. Extract entities**

For each `domain_model` file, read it and extract:
- Entity `name` (the primary struct/class)
- `id_field`: field name that holds the entity's primary identifier
- `states`: all possible values of any status/state enum/field

**6. Extract ID types**

Search for identifier fields and types (things named `*ID`, `*Id`, `*_id`, `*Key`). For each:
- Record its `name`, `format` (UUID, ULID, integer, etc.), `creator` (which component creates it), and `used_in` (where else it appears).

**7. Extract flows**

For each handler/entry-point (layer 1 or lambda), trace the call chain 2–3 levels deep using the Read tool. Record as a flow with `name`, `entry` (`file.go:FunctionName`), and `steps` (`[file.go:Fn, ...]`).

**8. Build `section_file_map`**

Invert the per-file `feeds_sections` into a section → file list map:

```python
section_file_map = {}
for file in files:
    for section in file.feeds_sections:
        section_file_map[section].append(file.path)
```

Deduplicate paths per section.

**9. Detect architecture**

From imports/config/dependency manifests, detect:
- Languages in use
- Key frameworks (web, ORM, testing)
- Databases (type + table/collection names where discoverable)
- Message queues (type + queue/topic names)
- External service integrations

**10. Write the index**

Write `docs/codebase-index.json`. Create `docs/` if it does not exist.

---

### Mode B — Targeted update (`--files` list provided)

Input: a comma-separated list of file paths that changed.

1. Read the existing `docs/codebase-index.json`.
2. For each file in the changed list:
   - If **deleted**: remove its entry from `files[]`. Remove it from any `component.files[]` lists. Rebuild that component's deps.
   - If **new**: classify it (component_type, symbols, feeds_sections, last_modified_sha) and add to `files[]`. Assign it to a component or create a new one.
   - If **modified**: re-read the file, update its `symbols`, `feeds_sections`, and `last_modified_sha`. Update any entity/flow entries it contributes to.
3. Rebuild `section_file_map` from the full updated `files[]`.
4. Update `meta.generated_at` to today and `meta.git_sha` to the current HEAD.
5. Write the updated index.

**Do not re-read files not in the changed list.**

---

## Parameters

- `--output <path>`: Override output path (default: `docs/codebase-index.json`)
- `--fresh`: Re-index all files even if an index already exists
- `--files <file1,file2,...>`: Only update these specific files (targeted Mode B)

---

## Notes

- **Correctness over completeness.** 80% of files accurately classified beats 100% guessed. When uncertain about `component_type`, use `other`.
- **Do not deep-index test files.** Mark them `component_type: "test"` with `feeds_sections: ["Testing Approach"]` and skip symbol extraction.
- **Skip generated code.** `*_generated.go`, `*.pb.go`, `mock_*.go`, `__pycache__/`, etc. add noise without signal.
- **`section_file_map` is the highest-value output.** The entire targeted-refresh optimisation depends on it being accurate. Invest care in assigning `feeds_sections` correctly per file.
- **Symbols should be exported names only.** Capitalised in Go; public in Python/TS. Skip private helpers.
- **Deps are best-effort.** Derive from import statements and config where obvious. Do not guess.
- If `docs/` does not exist, create it.
