# zelda_elt_pipeline

An ELT pipeline that pulls data from the [Zelda API](https://zelda.fanapis.com/), lands it in PostgreSQL, and transforms it with dbt — tested, modeled, and scheduled to run automatically.
This demonstration is to show my skills in terms of fundamentals of data engineering. Because it's the basics that makes a data engineer, not the tools. 
This demonstrates medallion architecture, Kimball, Star Schema, ELT, Idempotent, Incremental load....

Currently in development and about for improvement:
1) Retries with exponential backoff on API errors. Five tries, exponential backoff (1s, 2s, 4s, 8s, 16s), only retries on network/HTTP errors. 
2) Dead-letter queue for bad rows a missing field, a garbage date, an unexpected JSON shape.If it fails, log the bad payload to deadletter tables and keep going with the rest.
3) Checkpoint state in a table. For idempotent APIs (everything's keyed by id with UPSERTs downstream), this is a "save time on retries" optimization. For non-idempotent ones (event streams, paginated logs), it's required correctness.

## Architecture
Zelda API  ──▶  Python (Extract + Load)  ──▶  Postgres (raw schema)  ──▶  dbt (Transform + Test)  ──▶  Postgres (analytics schema)

Orchestrated by a PowerShell script (`zelda_run.ps1`) triggered via Windows Task Scheduler.

## Tech stack

- **Python** — extracts data from the Zelda API and loads it into Postgres raw tables
- **PostgreSQL** — storage layer for both raw and transformed data
- **dbt** — handles transformations, tests, models, and reusable macros
- **PowerShell + Windows Task Scheduler** — runs the pipeline on a schedule while the machine is on

## Project structure

zelda_elt_pipeline/
├── extract_load/          # Python scripts that hit the Zelda API and load to Postgres
├── dbt/                   # dbt project
│   ├── models/            # staging + mart models
│   ├── macros/            # reusable SQL macros
│   └── tests/             # custom data tests
├── zelda_run.ps1          # orchestration script for Task Scheduler
└── README.md

## Setup

### Prerequisites
- Python 3.10+
- PostgreSQL (local or remote)
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
Create a `.env` file in the project root:
```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=zelda
POSTGRES_USER=your_user
POSTGRES_PASSWORD=your_password
```

### 4. Configure dbt
Update `~/.dbt/profiles.yml` with your Postgres credentials so dbt can connect.

## Running the pipeline

### Manually
```bash
# Extract + Load
python extract_load/run.py

# Transform + Test
cd dbt
dbt run
dbt test
```

### Automated (Windows Task Scheduler)
The included `zelda_run.ps1` script runs the full pipeline end-to-end. To schedule it:

1. Open **Task Scheduler** → *Create Task*
2. Trigger: pick your cadence (daily, hourly, etc.)
3. Action: *Start a program*
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File "C:\path\to\zelda_elt_pipeline\zelda_run.ps1"`
4. Save and enable

The pipeline runs whenever the device is on at the scheduled time.

## Data models

The dbt project follows the staging → marts pattern:
- **staging** — light cleanup of raw API data (renaming, type casting)
- **marts** — analytics-ready tables for downstream consumption

Tests cover uniqueness, not-null constraints, and referential integrity for key fields.

## Roadmap
- [ ] Move from Task Scheduler to a proper orchestrator (Airflow / Prefect / Dagster)
- [ ] Containerize with Docker
- [ ] Add CI for dbt tests on PRs
- [ ] Deploy to cloud (so it stops depending on my laptop being on)

