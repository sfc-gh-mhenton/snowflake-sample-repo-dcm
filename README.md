# Snowflake Intelligence CI/CD with DCM (Hybrid Model)

This repository demonstrates a **hybrid CI/CD approach** for Snowflake Intelligence agents using **DCM (Database Change Management)** for infrastructure and custom GitHub Actions for AI objects.

## How This Differs from the Base Repo

This repo (`snowflake-sample-repo-dcm`) is a companion to [`snowflake-sample-repo`](https://github.com/sfc-gh-mhenton/snowflake-sample-repo), which uses custom Python scripts for the same pipeline. Both deploy equivalent agents to the same Snowflake account with `_DCM` suffix names.

### Side-by-Side Comparison

| Feature | `snowflake-sample-repo` | `snowflake-sample-repo-dcm` (this repo) |
|---|---|---|
| Infrastructure management | Custom SQL scripts (`CREATE IF NOT EXISTS`) | `snow dcm plan/deploy` (declarative) |
| Multi-environment config | `databases.yaml` + `resolve_databases.py` | DCM `manifest.yml` + Jinja templating |
| Schema/table idempotency | `CREATE IF NOT EXISTS` / `CREATE OR REPLACE` | `DEFINE` keyword (true declarative state) |
| Change detection (infra) | Planned `detect_changes.py` (git diff) | `snow dcm plan` (compares desired vs actual) |
| Change detection (AI) | `detect_changes.py` (git diff) | Still git diff (DCM limitation) |
| Deployment history | Custom `DEPLOY_HISTORY` table | `snow dcm list-deployments` (built-in) |
| SQL validation | Custom `validate_sql.py` | `snow dcm raw-analyze` (built-in) |
| Column lineage | Not available | `snow dcm raw-analyze` (built-in) |
| Data quality tests | Not available | `snow dcm test` (built-in) |
| AI object deployment | Custom scripts | Same custom scripts (DCM limitation) |
| Production trigger | Manual `workflow_dispatch` | Git tag (e.g., `v1.0.0`) |
| Prod safety gate | None (planned) | Auto DROP detection in `release.yaml` |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Phase 1: DCM Infrastructure                             │
│  ┌──────────────────────────────────────────────────┐   │
│  │  snow dcm plan → snow dcm deploy                 │   │
│  │  (schemas, tables, SQL functions, grants)         │   │
│  └──────────────────────────────────────────────────┘   │
│                         │                                │
│  Phase 2: Seed Data     ▼                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │  resolve_databases.py → snow sql                  │   │
│  │  (MERGE INTO KNOWLEDGE_BASE_DCM)                  │   │
│  └──────────────────────────────────────────────────┘   │
│                         │                                │
│  Phase 3: AI Objects    ▼                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │  envsubst post_deploy.sql → snow sql              │   │
│  │  (semantic view, search service)                  │   │
│  │  resolve_databases.py agent_spec → CREATE AGENT   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Object Types and Management

| Object Type | Managed By | Why |
|---|---|---|
| Schemas | DCM (`DEFINE SCHEMA`) | Supported by DCM |
| Tables | DCM (`DEFINE TABLE`) | Supported by DCM |
| SQL Functions | DCM (`DEFINE FUNCTION`) | Supported by DCM |
| Grants | DCM (`GRANT ... TO ROLE`) | Supported by DCM |
| Semantic Views | `post_deploy.sql` + `envsubst` | **Not supported** by DCM |
| Cortex Search Services | `post_deploy.sql` + `envsubst` | **Not supported** by DCM |
| Cortex Agents | GitHub Actions step | **Not supported** by DCM |
| Streamlit Apps | GitHub Actions + Git Repo | **Not supported** by DCM |

## Repository Structure

```
├── dcm/                              # DCM project (infrastructure)
│   ├── manifest.yml                  # Multi-env targets with Jinja vars
│   ├── post_deploy.sql               # AI objects (semantic views, search)
│   └── sources/definitions/
│       ├── infrastructure.sql        # DEFINE SCHEMA
│       ├── tables.sql                # DEFINE TABLE
│       ├── tools.sql                 # DEFINE FUNCTION
│       └── access.sql                # GRANTs
│
├── snowflake/                        # AI objects (not DCM-managed)
│   └── agents/intelligence/
│       └── tpch_sales_assistant_dcm/
│           └── agent_spec.yaml
│
├── infrastructure/
│   ├── databases.yaml                # DB name mapping (for agent spec resolution)
│   ├── scripts/                      # Shared utility scripts
│   │   ├── resolve_databases.py
│   │   └── validate_agent_spec.py
│   └── seed/
│       └── seed_knowledge_base_dcm.sql
│
└── .github/workflows/
    ├── ci.yaml                       # PR validation (DCM analyze + lint)
    ├── evaluate.yaml                 # Merge to main → deploy to TEST
    └── release.yaml                  # Tag push → TEST gate → PROD deploy
```

## Workflows

### CI (`ci.yaml`) - On Pull Request
- Lints YAML files
- Validates agent specifications
- Runs `snow dcm raw-analyze` for static validation
- Verifies Snowflake connectivity

### Evaluate (`evaluate.yaml`) - On Push to Main
- DCM plan + deploy to TEST
- Seeds knowledge base data
- Deploys AI objects (semantic view, search, agent)
- Verifies all objects exist

### Release (`release.yaml`) - On Tag Push (`v*`)
- Deploys to TEST (full pipeline)
- Checks for DROP operations in PROD plan (safety gate)
- Deploys to PROD
- Creates GitHub Release with deployment summary

## Quick Start

### Prerequisites
- Snowflake CLI 3.17+ (`snow --version`)
- GitHub CLI (`gh`)
- Python 3.11+

### Local Development
```bash
# Analyze definitions (static check)
cd dcm
snow dcm raw-analyze --target DEV -c default

# Preview changes
snow dcm plan --target DEV --save-output -c default

# Deploy infrastructure
snow dcm deploy --target DEV -c default

# Deploy AI objects
export DB=INTELLIGENCE_DEV_DB
export SAMPLE_DB=SNOWFLAKE_SAMPLE_DATA
envsubst < post_deploy.sql | snow sql --stdin -c default
```

### Creating a Production Release
```bash
git tag v1.0.0
git push origin v1.0.0
# release.yaml triggers: TEST → eval gate → PROD
```

## Environment Configuration

Environments are managed through two mechanisms:

1. **DCM Jinja** (for infrastructure): `manifest.yml` defines `{{db}}` and `{{sample_db}}` variables per target
2. **Shell substitution** (for AI objects): `envsubst` replaces `${DB}` and `${SAMPLE_DB}` in `post_deploy.sql`
3. **Python resolution** (for agent spec): `resolve_databases.py` replaces `__DATABASE__` placeholders

| Environment | Database | DCM Target | DCM Project Name |
|---|---|---|---|
| DEV | `INTELLIGENCE_DEV_DB` | `DEV` | `...INTELLIGENCE_PROJECT_DCM_DEV` |
| TEST | `INTELLIGENCE_TEST_DB` | `TEST` | `...INTELLIGENCE_PROJECT_DCM_TEST` |
| PROD | `INTELLIGENCE_DB` | `PROD` | `...INTELLIGENCE_PROJECT_DCM` |
