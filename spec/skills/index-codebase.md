# Skill: Index Codebase

Build or update `docs/codebase-index.json` — a structured map of the codebase. This index is the shared source of truth used by the `write-overview-doc`, `detect-git-changes`, `generate-diagram`, and `explore-repo-interface` skills.

## When to use this skill

- Called by `codebase-overview` before writing the overview doc
- Called by `architecture-diagram` when no index exists yet
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
    "Domain Models": ["internal/domain/delivery.go"],
    "E2E Flows": ["internal/rest/handler.go", "internal/service/delivery.go"],
    "Data Layer": ["internal/repo/delivery_repo.go"]
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

---

## Instructions

### Mode A — Full index (first run or `--fresh`)

**1. Get current git SHA**

```bash
git rev-parse HEAD
```

Record in `meta.git_sha`. If not a git repo, use `null`.

**2. Discover all significant files**

Find source files. Skip:
- `vendor/`, `node_modules/`, `.git/`, `dist/`, `build/`, `.cache/`
- Generated files: `*_generated.go`, `*.pb.go`, `mock_*.go`, `__pycache__/`
- Binary artefacts: `*.so`, `*.dylib`, `*.exe`, `*.wasm`

Group by type: source files (`*.go`, `*.py`, `*.ts`, `*.js`, `*.java`, `*.rs`), config (`*.yaml`, `*.yml`, `*.toml`), infra (`*.tf`, `docker-compose.yml`, `k8s/`).

**3. Classify each file**

For every significant file:

- **`component_type`**: infer from path and content.
- **`symbols`**: read the file and extract all exported names:
  - Go: `type Foo struct`, `func (r *T) Foo(`
  - Python: `class Foo`, `def foo` (public)
  - TypeScript/JS: `export const`, `export function`, `export class`
- **`feeds_sections`**: apply the File → Section Mapping Table above.
- **`last_modified_sha`**: `git log -1 --format="%H" -- <filepath>`. Use `null` if not in git.

**4. Build components**

Group files into logical deployable/logical units. Each component:
- `id`: URL-slug (e.g. `delivery-api`)
- `name`: human-readable
- `type`: api | service | worker | lambda | consumer | cron | data_store | queue | external
- `layer`: 0–4
- `files`: list of file paths
- `deps`: list of other component IDs (derive from imports and config)

**5. Extract entities**

For each `domain_model` file, extract:
- Entity `name`, `id_field`, and `states`.

**6. Extract ID types**

Search for identifier fields (`*ID`, `*Id`, `*_id`, `*Key`). Record `name`, `format`, `creator`, `used_in`.

**7. Extract flows**

For each handler/entry-point (layer 1 or lambda), trace the call chain 2–3 levels deep. Record as a flow with `name`, `entry`, and `steps`.

**8. Build `section_file_map`**

Invert the per-file `feeds_sections` into a section → file list map. Deduplicate paths per section.

**9. Detect architecture**

From imports/config/dependency manifests: languages, frameworks, databases, queues, external services.

**10. Write the index**

Write `docs/codebase-index.json`. Create `docs/` if it does not exist.

---

### Mode B — Targeted update (`--files` list provided)

1. Read the existing `docs/codebase-index.json`.
2. For each file in the changed list:
   - **Deleted**: remove its entry from `files[]`, rebuild component deps.
   - **New**: classify and add to `files[]`, assign to a component.
   - **Modified**: re-read the file, update `symbols`, `feeds_sections`, `last_modified_sha`.
3. Rebuild `section_file_map` from the full updated `files[]`.
4. Update `meta.generated_at` and `meta.git_sha`.
5. Write the updated index.

**Do not re-read files not in the changed list.**

---

## Parameters

- `--output <path>`: Override output path (default: `docs/codebase-index.json`)
- `--fresh`: Re-index all files even if an index already exists
- `--files <file1,file2,...>`: Only update these specific files (targeted Mode B)

---

## Notes

- **Correctness over completeness.** When uncertain about `component_type`, use `other`.
- **Do not deep-index test files.** Mark `component_type: "test"` and skip symbol extraction.
- **Skip generated code.**
- **`section_file_map` is the highest-value output.** The targeted-refresh optimisation depends on it.
- **Symbols should be exported names only.**
- **Deps are best-effort.** Derive from imports where obvious. Do not guess.
