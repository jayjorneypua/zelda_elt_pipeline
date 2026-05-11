# Zelda ELT Pipeline

An ELT pipeline that pulls data from the [Zelda API](https://zelda.fanapis.com/), lands it in PostgreSQL, and transforms it with dbt — tested, modeled, snapshotted, and scheduled to run automatically.

This project is a demonstration of data engineering fundamentals through a real working pipeline. The focus is on *patterns*, not specific vendors — these same patterns work whether the warehouse is Postgres, Snowflake, BigQuery, or anything else.

## What this project demonstrates

- **Medallion architecture** — `raw` → `snapshots` → `staging` → `intermediate` → `marts`
- **Kimball-style star schemas** — facts surrounded by conformed dimensions
- **ELT, not ETL** — Python handles extract + load only; dbt owns all transformation in SQL
- **Idempotency at every layer** — re-running the pipeline produces the same end state
- **Slowly Changing Dimensions (SCD Type 2)** — historical versioning via dbt snapshots
- **Surrogate keys** — generated via `dbt_utils`, decoupling joins from source IDs
- **Conformed dimensions** — `dim_game` reused across multiple fact tables
- **Data quality testing** — `not_null`, `unique`, `relationships` tests on every model
- **Retries with exponential backoff** — transient network failures handled automatically (1s → 2s → 4s → 8s → 16s, up to 5 attempts)
- **Structured logging** — rotating pipeline log + separate errors log for fast triage
- **Scheduled orchestration** — Windows Task Scheduler runs the pipeline daily

## Architecture

```
Zelda API
   │
   ▼
Python (Extract + Load, with retries)
   │
   ▼
PostgreSQL — raw schema (idempotent UPSERT, JSONB payload preserved)
   │
   ├──▶ dbt snapshot — SCD2 history per source
   │         │
   │         ▼
   │      analytics_marts.dim_* (with valid_from / valid_to / is_current)
   │
   └──▶ dbt staging (typed columns from JSONB)
            │
            ▼
        dbt intermediate (JSON array unnesting)
            │
            ▼
        analytics_marts.fct_* (joined to conformed dims on surrogate keys)
```

Orchestrated by a PowerShell script (`zelda_run.ps1`) triggered via Windows Task Scheduler.

## Tech stack

- **Python 3.12** — extractors using `requests` for HTTP, `tenacity` for retry, `psycopg2` for Postgres, `python-dotenv` for config
- **PostgreSQL 14+** — single warehouse for raw and transformed data; JSONB for flexible schema-on-read at the raw layer
- **dbt-postgres** — transformations, snapshots, tests, macros, lineage
- **dbt-utils** — surrogate key generation
- **PowerShell + Windows Task Scheduler** — orchestration

## Sources covered

| Source endpoint | Entity | Relationships |
|---|---|---|
| `/staff` | Game development staff | → games |
| `/games` | Zelda titles | (conformed dim, used by many facts) |
| `/characters` | In-universe characters | → games |
| `/monsters` | In-universe monsters | → games |
| `/dungeons` | Dungeons | (referenced by bosses, places) |
| `/bosses` | Boss fights | → games, dungeons |
| `/places` | In-universe locations | → characters |

## Data models

Star schemas built on conformed dimensions. Every fact joins one or more dims via the surrogate key, with an `is_current = true` filter for SCD2-aware joins.

**Dimensions:** `dim_staff`, `dim_game`, `dim_character`, `dim_monster`, `dim_dungeon`, `dim_boss`, `dim_place`

**Facts:**
- `fct_staff_games` — staff ↔ games
- `fct_character_appearances` — characters ↔ games
- `fct_monster_appearances` — monsters ↔ games
- `fct_boss_appearances` — bosses ↔ games
- `fct_boss_dungeons` — bosses ↔ dungeons
- `fct_place_inhabitants` — places ↔ characters

Every model has tests for primary key uniqueness, foreign key relationships, and required field presence.

## Project structure

```
zelda_elt_pipeline/
├── extract/                      # Python: extract + load
│   ├── common.py                 # shared logic: retries, logging, upsert
│   ├── extract_staff.py          # one file per endpoint
│   ├── extract_games.py
│   ├── extract_characters.py
│   ├── extract_monsters.py
│   ├── extract_dungeons.py
│   ├── extract_bosses.py
│   ├── extract_places.py
│   └── run_all.py                # runs every extractor in sequence
├── zelda_warehouse/              # dbt project
│   ├── models/
│   │   ├── staging/              # raw → typed columns (views)
│   │   ├── intermediate/         # unnesting, reshapes (views)
│   │   └── marts/                # dims + facts (tables)
│   ├── snapshots/                # SCD2 definitions
│   ├── macros/                   # reusable Jinja macros
│   ├── tests/                    # singular data tests
│   └── dbt_project.yml
├── logs/                         # rotating log files (gitignored)
├── zelda_run.ps1                 # orchestration script
├── .env.example                  # connection config template
└── README.md
```

## Setup

### Prerequisites

- Python 3.12
- PostgreSQL 14+ (local or remote)
- dbt-postgres (`pip install dbt-postgres`)

### 1. Clone the repo

```bash
git clone https://github.com/jayjorneypua/zelda_elt_pipeline.git
cd zelda_elt_pipeline
```

### 2. Install Python dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure environment variables

Copy `.env.example` to `.env` and fill in your Postgres connection:

```
POSTGRES_DSN=postgresql://user:password@localhost:5432/your_db
```

### 4. Configure dbt

Set up `~/.dbt/profiles.yml` with a `zelda_warehouse` profile pointing at your Postgres instance.

### 5. Install dbt packages

```bash
cd zelda_warehouse
dbt deps
```

## Running the pipeline

### Manually (full pipeline)

```bash
# Pull from API, land in raw
python extract/run_all.py

# Run dbt snapshots, models, and tests
cd zelda_warehouse
dbt snapshot
dbt build
```

### One model at a time (during development)

```bash
dbt build --select stg_zelda__staff        # just this model
dbt build --select dim_boss+               # this model and everything downstream
dbt build --select +fct_boss_appearances   # this model and everything upstream
```

### Automated (Windows Task Scheduler)

The `zelda_run.ps1` script runs the full pipeline end-to-end and writes timestamped logs to `logs/`. To schedule:

1. Open **Task Scheduler** → *Create Task*
2. Trigger: daily at your chosen time
3. Action: *Start a program*
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File "C:\path\to\zelda_run.ps1"`
4. Save and enable

The pipeline runs whenever the machine is on at the scheduled time.

## Logging

The pipeline writes to three places, configured via Python's `dictConfig`:

- **Console** — live stream of every step
- **`logs/pipeline.log`** — full INFO+ history with rotation (10 MB per file, 5 backups kept)
- **`logs/errors.log`** — ERROR-only file for fast triage when something breaks

Failed API requests trigger automatic retries with exponential backoff (via `tenacity`); only exhausted retries surface as ERROR.

## What's coming next

In active development:

- [ ] **Dead-letter queue** — bad rows (missing fields, malformed payloads, structurally broken records) get routed to a `raw.unidentified` quarantine table at load time; semantic validation lives in a reusable dbt macro (`dead_letter_check`) feeding an `int_dead_letters` model. Singular dbt tests fire when bad-row counts exceed thresholds.
- [ ] **Checkpoint state** — a `meta.extraction_state` table to make extracts resumable; on partial failure, the next run picks up from the last successful page instead of re-pulling from page 0.

Longer-term roadmap:

- [ ] Replace Task Scheduler with a proper orchestrator (Dagster preferred for its native dbt integration)
- [ ] Containerize with Docker
- [ ] CI for dbt tests on PRs via GitHub Actions
- [ ] Add a BI layer (Metabase or Streamlit) on top of the marts to close the loop visually
- [ ] Port the warehouse to a cloud DW (Snowflake or BigQuery free tier) to show portability
- [ ] Apply the same patterns to a file-based source (CSV/Excel) to demonstrate source-agnostic design
