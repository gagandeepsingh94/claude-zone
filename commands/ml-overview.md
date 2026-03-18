---
description: Deeply explore an ML codebase and generate (or refresh) a comprehensive ml-overview.md covering model types, training pipelines, data sources, feature engineering, evaluation, serving, and monitoring.
---

# ML Codebase Overview Generator

Deeply explore the current repository's machine learning components and produce (or intelligently update) `docs/ml-overview.md`.

## Purpose

Produces a single reference document that answers the questions every engineer and data scientist asks when joining an ML project: What models exist? How are they trained? Where does the data come from? How do experiments get tracked? How do models get to production? What breaks in subtle ways?

Works in:
- **Pure ML repos** (research, training pipelines, notebooks)
- **Hybrid repos** (ML models embedded in a larger service — complement with `/codebase-overview`)

---

## Instructions

### Step 0 — Handle `--help`

If the user passes `--help` or `-h`, print the following and do nothing else:

```
/ml-overview — Generate or refresh a comprehensive ML codebase overview doc

USAGE
  /ml-overview [options]

DESCRIPTION
  Scans the current repo for ML artefacts (models, training scripts, notebooks,
  experiment tracking, feature stores, serving code) and writes docs/ml-overview.md
  covering: model inventory, data sources, feature engineering, training pipelines,
  experiment tracking, evaluation, serving/inference, retraining triggers, monitoring,
  drift detection, and environment/reproducibility.

  If the file already exists, merges new findings rather than overwriting.

  Works in pure ML repos and hybrid repos (ML embedded in a larger service).
  For the general service architecture in a hybrid repo, also run /codebase-overview.

OPTIONS
  --output <path>    Override output path (default: docs/ml-overview.md)
  --focus <area>     Give extra depth to one area, e.g. --focus "training pipeline"
                     or --focus "data" or --focus "serving"
  --fresh            Skip merge — write a completely new file from scratch
  --help, -h         Show this help and exit

EXAMPLES
  /ml-overview
  /ml-overview --fresh
  /ml-overview --focus "data sources"
  /ml-overview --focus "serving" --output docs/serving-overview.md

OUTPUT FILES (default)
  docs/ml-overview.md

RELATED SKILLS
  /codebase-overview      — General service architecture (complement for hybrid repos)
  /architecture-diagram   — Visual diagram of the ML pipeline
  /ecosystem-overview     — Cross-repo view if ML is one service among many
```

### Step 1 — Detect existing ML overview

Check whether `docs/ml-overview.md` (or `--output` path) already exists.

- **Does NOT exist** → fresh generation, proceed to Step 2.
- **Does exist** → read it in full, note the `Last updated` line, then proceed to Step 2. You will merge rather than replace.

### Step 2 — Read existing docs

Read the following if present:
- `CLAUDE.md` / `README.md`
- `docs/codebase-overview.md` (to avoid duplication with general architecture)
- Any other files in `docs/`

### Step 3 — Detect ML artefacts

Scan the repo for signals of ML code. Look for (non-exhaustive):

**Model files & frameworks:**
- `*.pt`, `*.pth`, `*.ckpt`, `*.pb`, `*.h5`, `*.onnx`, `*.pkl`, `*.joblib`, `*.safetensors`
- Imports: `torch`, `tensorflow`, `keras`, `sklearn`, `xgboost`, `lightgbm`, `catboost`, `jax`, `flax`, `transformers`, `diffusers`, `spacy`, `nltk`

**Training infrastructure:**
- `train.py`, `fit.py`, `run_training.py`, files with `trainer` in name
- `Makefile` targets: `train`, `finetune`, `evaluate`
- SageMaker: `estimator`, `TrainingJob`, `HyperparameterTuner`
- Vertex AI: `CustomTrainingJob`, `AutoML`
- Kubernetes: `Job` specs with GPU requests

**Data pipelines:**
- `data/`, `datasets/`, `raw/`, `processed/`, `features/`
- DVC: `*.dvc`, `dvc.yaml`, `dvc.lock`
- Airflow: `dags/`, `DAG(`, `PythonOperator`
- Prefect / Luigi / Metaflow / Kedro config files
- S3/GCS/Azure Blob paths in config or code

**Experiment tracking:**
- `mlflow`, `wandb`, `comet_ml`, `neptune`, `clearml`, `tensorboard`
- `experiment_tracking/`, `runs/`, `artifacts/`

**Feature engineering:**
- `feast`, `tecton`, `hopsworks` imports
- `feature_store`, `features.py`, `feature_pipeline`

**Serving / inference:**
- `serve.py`, `inference.py`, `predictor.py`, `handler.py`
- `torchserve`, `triton`, `bentoml`, `ray serve`, `seldon`, `kfserving`
- FastAPI/Flask endpoints that load a model

**Evaluation:**
- `evaluate.py`, `metrics.py`, `eval/`
- `sklearn.metrics`, `evaluate` library, `torchmetrics`

**Notebooks:**
- `*.ipynb` files — read their titles and first few cells

### Step 4 — Deep exploration

Using the artefacts found in Step 3, read the key files. Cover:

1. **Model inventory** — every distinct model in the repo, its framework, architecture, task type
2. **Training pipelines** — entry points, config/hyperparameter management, hardware requirements
3. **Data sources** — origin (database, S3, API, synthetic, HuggingFace Hub, Kaggle, internal), format, volume if documented
4. **Data versioning** — DVC, LFS, manifest files, or none
5. **Feature engineering** — preprocessing steps, feature stores, online vs offline features
6. **Experiment tracking** — tool used, what is logged (metrics, artefacts, params, model versions)
7. **Evaluation strategy** — metrics, validation approach (hold-out, k-fold, time-based split), benchmark datasets
8. **Model registry & versioning** — how trained models are stored and promoted
9. **Serving / inference** — deployment target, serving framework, batch vs real-time, latency/throughput requirements if documented
10. **Monitoring & drift detection** — tools, what is monitored, alerting
11. **Retraining triggers** — scheduled, performance-degradation-triggered, data-volume-triggered, or manual
12. **Environment & dependencies** — Python version, key package versions, CUDA/hardware requirements, Docker images

### Step 5 — Generate content

Produce all required sections (see below). Always include concrete file paths: `src/train.py: Trainer.fit()`. For notebooks, reference `notebooks/01_exploration.ipynb`.

### Step 6 — Merge with existing file (if one exists)

**Do NOT blindly overwrite.** Apply these merge rules per section:
- **Structurally changed** (new models, renamed pipelines, removed flows) → replace with new content.
- **Additive only** (new experiments, new data sources, new nuances) → merge new items in; keep existing items that are still accurate.
- **Unchanged** → keep existing wording.
- **Uncertain** → keep existing content and append `<!-- verify -->`.

### Step 7 — Write the final file

Start the output file with:

```
<!-- Last updated: YYYY-MM-DD -->
```

Then a cross-reference block, followed by the full content.

---

## Required Sections

### 1. ML Components at a Glance
A concise table of every model/pipeline in the repo:

| Model / Pipeline | Task Type | Framework | Status | Entry Point |
|-----------------|-----------|-----------|--------|-------------|
| e.g. demand-forecaster | Time-series regression | PyTorch + Lightning | Production | `train/forecast/train.py` |

### 2. Model Inventory — Deep Dive
Per model: architecture details, input/output schema, key hyperparameters, any pretrained base (e.g. `bert-base-uncased`), and where the final artefact lives.

### 3. Data Sources & Ingestion
- Where raw data comes from (with paths/URIs if present in code)
- Data formats and schemas
- Data versioning strategy (DVC, manifests, or none)
- Any data quality / validation steps

### 4. Feature Engineering Pipeline
- Preprocessing steps and where they live
- Feature store usage (online vs offline)
- Train/inference feature parity — are features computed the same way at training time and serving time? (common source of bugs)

### 5. Training Pipelines
- How to trigger a training run (commands, CI jobs, SageMaker/Vertex)
- Config / hyperparameter management (Hydra, OmegaConf, argparse, YAML, etc.)
- Distributed training setup if present
- Hardware requirements (GPU type, memory)
- Approximate training duration if documented

### 6. Experiment Tracking & Model Registry
- Tool used and what is logged
- How to find past experiments
- Model promotion workflow (staging → production)
- Artefact storage location

### 7. Evaluation & Metrics
- Primary and secondary metrics per model/task
- Validation strategy (hold-out, k-fold, time-based split, A/B test)
- Benchmark datasets or baselines
- Where evaluation scripts live

### 8. Serving & Inference
- Deployment target and serving framework
- Batch vs real-time vs streaming
- Input/output contract (request/response schema)
- Model loading pattern (cold start, caching, warm pools)
- Latency / throughput SLAs if documented

### 9. Retraining & Continuous Learning
- What triggers retraining (schedule, drift threshold, manual, data volume)
- End-to-end retraining flow with file paths
- How new model versions are validated before promotion

### 10. Monitoring & Drift Detection
- What is monitored in production (prediction distribution, feature drift, latency, error rate)
- Tool used (Evidently, WhyLabs, Arize, custom, none)
- Alerting thresholds if configured

### 11. E2E ML Flows with Code Paths
For each major flow, trace the exact path:
- **Training flow**: raw data → features → train → evaluate → register
- **Inference flow**: request → feature lookup → model.predict() → response
- **Retraining flow**: trigger → data pull → train → evaluate → promote

### 12. Tricky Parts & ML-Specific Nuances
Non-obvious issues. Examples of things to look for and document:
- Train/serving skew (features computed differently at train vs serve time)
- Data leakage risks in the feature pipeline
- Class imbalance handling
- Non-determinism sources (random seeds, GPU ops)
- Cold-start behaviour for new entities
- Latency cliffs (model too slow for real-time without batching)
- Version pinning issues (model trained on numpy X, served on numpy Y)
- Implicit assumptions in preprocessing (e.g. "assumes UTC timestamps")

### 13. Environment & Reproducibility
- Python version, key package versions
- How to reproduce the environment (`pip install -r requirements.txt`, conda, poetry, Docker)
- CUDA / hardware requirements
- Known reproducibility issues (non-deterministic ops, etc.)

### 14. Key File Quick Reference
Table of the most important files with single-line purpose.

---

## Parameters

- `--output <path>`: Override output file path (default: `docs/ml-overview.md`)
- `--focus <area>`: Give extra depth to a specific area (e.g. `--focus "training pipeline"`, `--focus "serving"`, `--focus "data"`)
- `--fresh`: Skip merge logic and write a completely fresh file

## Examples

### Example 1: First-time generation
When the user says "/ml-overview" and no ML overview exists, explore the codebase and create `docs/ml-overview.md`.

### Example 2: Refreshing after new model added
When the user says "/ml-overview" and `docs/ml-overview.md` already exists, detect what changed (new models, new pipelines), merge the new content, and update the `Last updated` date.

### Example 3: Force fresh
When the user says "/ml-overview --fresh", ignore any existing file and write a completely new one.

### Example 4: Deep focus on data
When the user says "/ml-overview --focus 'data sources'", give extra depth to data ingestion, versioning, and feature engineering while still covering all required sections.

## Notes

- The `<!-- Last updated: YYYY-MM-DD -->` line must always be the first line of the output file.
- **Train/serving skew** is the single most common source of silent ML bugs — always investigate whether features are computed identically at training and serving time and document what you find.
- For notebooks (`*.ipynb`), read the markdown cells and cell outputs, not just the code. They often contain the best explanation of intent.
- If no experiment tracking is found, note this explicitly — it is a significant operational risk.
- If `docs/` does not exist, create it.
- When merging, never silently delete existing nuances — use `<!-- verify -->` if unsure whether they're still accurate.
- Use GitHub-Flavored Markdown with ASCII diagrams — no external diagram dependencies.
- If the repo also has non-ML service code, note at the top: "For the general service architecture, see `docs/codebase-overview.md`. Run `/codebase-overview` to generate it."
