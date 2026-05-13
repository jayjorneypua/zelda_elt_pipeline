"""Shared logic for all Zelda API extractors."""

import os
import json
import time
import logging
import logging.config
from pathlib import Path

import requests
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
    before_sleep_log,
)

from datetime import datetime, timezone

SIMULATE_CRASH_AT_PAGE = None

# ──────────────────────────────────────────────────────────────────────────────
# Logging
# ──────────────────────────────────────────────────────────────────────────────
LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

logging.config.dictConfig({
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "standard": {
            "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "stream": "ext://sys.stdout",
            "level": "INFO",
            "formatter": "standard",
        },
        "file_all": {
            "class": "logging.handlers.RotatingFileHandler",
            "level": "INFO",
            "formatter": "standard",
            "filename": str(LOG_DIR / "pipeline.log"),
            "maxBytes": 10_000_000,
            "backupCount": 5,
            "encoding": "utf-8",
        },
        "file_errors": {
            "class": "logging.FileHandler",
            "level": "ERROR",
            "formatter": "standard",
            "filename": str(LOG_DIR / "errors.log"),
            "encoding": "utf-8",
        },
    },
    "root": {
        "level": "INFO",
        "handlers": ["console", "file_all", "file_errors"],
    },
    "loggers": {
        "urllib3": {"level": "WARNING"},
    },
})

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────────────────────────────────────
load_dotenv()
DSN = os.environ["POSTGRES_DSN"]
PAGE_SIZE = 50
SLEEP = 0.2

DDL = """

    CREATE SCHEMA IF NOT EXISTS raw;
    
    CREATE TABLE IF NOT EXISTS raw.zelda_{name} (
        id           TEXT PRIMARY KEY
      , payload      JSONB NOT NULL
      , extracted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

"""

UPSERT = """

    INSERT INTO raw.zelda_{name} (id, payload)
    VALUES %s
    ON CONFLICT (id) 
    DO UPDATE 
    SET
        payload      = EXCLUDED.payload,
        extracted_at = NOW()
    WHERE 
        raw.zelda_{name}.payload IS DISTINCT FROM EXCLUDED.payload;

"""

UNIDENTIFIED_DDL = """
    CREATE SCHEMA IF NOT EXISTS raw;

    CREATE TABLE IF NOT EXISTS raw.unidentified (
        raw_id          BIGSERIAL PRIMARY KEY
      , source_name     TEXT NOT NULL
      , raw_payload     JSONB NOT NULL
      , reason          TEXT
      , extracted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
"""

UNIDENTIFIED_INSERT = """
    INSERT INTO raw.unidentified (
        source_name, raw_payload, reason
    )
    VALUES %s;
"""

STATE_DDL = """
    CREATE SCHEMA IF NOT EXISTS meta;

    CREATE TABLE IF NOT EXISTS meta.extraction_state(
        source_name             TEXT PRIMARY KEY
      , status                  TEXT NOT NULL
      , last_completed_page     INTEGER
      , run_started_at          TIMESTAMPTZ
      , run_ended_at            TIMESTAMPTZ
      , error_message           TEXT
      , records_loaded          INTEGER NOT NULL DEFAULT 0
    )
"""

# ──────────────────────────────────────────────────────────────────────────────
# Fetch (with retries)
# ──────────────────────────────────────────────────────────────────────────────
@retry(
    stop=stop_after_attempt(5),

    wait=wait_exponential(multiplier=1, min=1, max=30),

    retry=retry_if_exception_type((
        requests.exceptions.ConnectionError,
        requests.exceptions.Timeout,
        requests.exceptions.HTTPError,
    )),

    before_sleep=before_sleep_log(logger, logging.WARNING),
    reraise=True,
)
def fetch_page(url, page, page_size):
    """Fetch one page from the API. Retries up to 5 times with exponential backoff."""

    response = requests.get(
        url,
        params={"page": page, "limit": page_size},   
        timeout=30,
    )

    response.raise_for_status()
    return response.json()

# ──────────────────────────────────────────────────────────────────────────────
# Load
# ──────────────────────────────────────────────────────────────────────────────
def load_to_raw(name, records):
    """Upsert records into raw.zelda_<name>."""

    good_records = []
    unidentified = []

    for record in records:
        if isinstance(record, dict) and record.get("id"):
            good_records.append(record)
        else:
            reason = "not_a_dict" if not isinstance(record, dict) else "missing_id"
            unidentified.append((name, json.dumps(record), reason))

    with psycopg2.connect(DSN) as connection, connection.cursor() as cursor:
        cursor.execute(DDL.format(name=name))
        cursor.execute(UNIDENTIFIED_DDL)

        if good_records:
            rows = [(record["id"], json.dumps(record)) for record in good_records]
            execute_values(cursor, UPSERT.format(name=name), rows)

        if unidentified:
            execute_values(cursor, UNIDENTIFIED_INSERT, unidentified)

    logger.info(
        "[%s] loaded %d rows, quarantined %d unidentified rows",
        name, len(good_records), len(unidentified),
    )
    return len(good_records), len(unidentified)


def initial_state_table():
    """Make sure meta.extraction_state exists."""
    with psycopg2.connect(DSN) as conn, conn.cursor() as cur:
        cur.execute(STATE_DDL)


def read_state(source_name):
    """Read the current state row for a source. Returns None if no row exists."""
    with psycopg2.connect(DSN) as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT status, last_completed_page, records_loaded "
            "FROM meta.extraction_state WHERE source_name = %s",
            (source_name,),
        )
        row = cur.fetchone()
    if row is None:
        return None
    return {
        "status": row[0],
        "last_completed_page": row[1],
        "records_loaded": row[2],
    }


def write_state(source_name, **fields):
    """Upsert state. Pass column-value pairs as kwargs."""
    if not fields:
        return
    cols = list(fields.keys())
    placeholders = ", ".join(["%s"] * len(cols))
    updates      = ", ".join([f"{c} = EXCLUDED.{c}" for c in cols])
    sql = f"""
        INSERT INTO meta.extraction_state (source_name, {', '.join(cols)})
        VALUES (%s, {placeholders})
        ON CONFLICT (source_name) DO UPDATE SET {updates}
    """
    with psycopg2.connect(DSN) as conn, conn.cursor() as cur:
        cur.execute(sql, [source_name] + list(fields.values()))

# ──────────────────────────────────────────────────────────────────────────────
# Top-level runner
# ──────────────────────────────────────────────────────────────────────────────
def run(name, url):
    """
    Pull from URL and load into raw.zelda_<name>, page by page,
    with resumable checkpoint state in meta.extraction_state.
    Returns (loaded_count, unidentified_count).
    """
    logger.info("=== Running extractor for '%s' ===", name)

    # initialize the meta.extraction_state table.
    initial_state_table()

    # Decide where to start based on previous run's state
    state = read_state(name)

    # if the previous run was interrupted(in_progress) or failed, continue where it left off and keep the previous loaded-record count. Otherwise start fresh. 
    if state and state["status"] in ("in_progress", "failed"):
        start_page = (state["last_completed_page"] or -1) + 1
        records_loaded = state["records_loaded"]

        logger.info(
            "[%s] resuming from page %d (previous run status: %s)",
            name, start_page, state["status"],
        )
    else:
        start_page = 0
        records_loaded = 0
        logger.info("[%s] starting fresh run from page 0", name)

    # Mark this run as in_progress
    now = datetime.now(timezone.utc)
    write_state(
        name,
        status = "in_progress",
        run_started_at = now,
        run_ended_at = None,
        error_message = None,
        records_loaded = records_loaded,
        last_completed_page = (start_page - 1) if start_page > 0 else None,
    )

    try:
        total_unidentified = 0
        page = start_page

        while True:
            # Optional crash injection for testing — set SIMULATE_CRASH_AT_PAGE at top of file
            if SIMULATE_CRASH_AT_PAGE is not None and page == SIMULATE_CRASH_AT_PAGE:
                raise RuntimeError(f"Simulated crash at page {SIMULATE_CRASH_AT_PAGE}")

            body = fetch_page(url, page, PAGE_SIZE)
            data = body.get("data", [])
            if not data:
                break

            loaded, unidentified = load_to_raw(name, data)
            records_loaded += loaded
            total_unidentified += unidentified

            # Checkpoint after this page is safely in raw
            write_state(
                name,
                status="in_progress",
                last_completed_page=page,
                records_loaded=records_loaded,
            )

            logger.info(
                "[%s] page %d: loaded %d (running total %d)",
                name, page, loaded, records_loaded,
            )

            if len(data) < PAGE_SIZE:
                break
            page += 1
            time.sleep(SLEEP)

        # Whole run finished cleanly
        write_state(
            name,
            status="completed",
            run_ended_at=datetime.now(timezone.utc),
            error_message=None,
        )
        logger.info(
            "[%s] completed: loaded=%d, unidentified=%d",
            name, records_loaded, total_unidentified,
        )
        return records_loaded, total_unidentified

    except Exception as e:
        # Mark failed; the next run will read last_completed_page and resume
        write_state(
            name,
            status="failed",
            run_ended_at=datetime.now(timezone.utc),
            error_message=str(e),
        )
        logger.exception("[%s] extractor failed", name)
        raise