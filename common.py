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
        id           TEXT PRIMARY KEY,
        payload      JSONB NOT NULL,
        extracted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

"""

UPSERT = """

    INSERT INTO raw.zelda_{name} (id, payload)
    VALUES %s
    ON CONFLICT (id) DO UPDATE SET
        payload      = EXCLUDED.payload,
        extracted_at = NOW()
    WHERE raw.zelda_{name}.payload IS DISTINCT FROM EXCLUDED.payload;

"""

UNIDENTIFIED_DDL = """
    CREATE SCHEMA IF NOT EXISTS raw;
    CREATE TABLE IF NOT EXISTS raw.unidentified (
        raw_id BIGSERIAL PRIMARY KEY,
        source_name TEXT NOT NULL,
        raw_payload JSONB NOT NULL,
        reason TEXT,
        extracted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
"""

UNIDENTIFIED_INSERT = """
    INSERT INTO raw.unidentified (source_name, raw_payload, reason)
    VALUES %s;
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


def fetch_all(url):
    """Paginate the API until we've pulled every record."""
    page = 0
    output = []
    logger.info("Starting fetch from %s", url)

    while True:

        body = fetch_page(url, page, PAGE_SIZE)
        data = body.get("data", [])

        if not data:
            break

        output.extend(data)

        logger.info(                               
            "page %d: fetched %d records (running total: %d)",
            page, len(data), len(output),
        )

        if len(data) < PAGE_SIZE:
            break

        page += 1
        time.sleep(SLEEP)

    logger.info("Finished fetch from %s — %d records total", url, len(output))
    return output


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


# ──────────────────────────────────────────────────────────────────────────────
# Top-level runner
# ──────────────────────────────────────────────────────────────────────────────
def run_pipeline(name, url):                                 
    """Pull from URL and load into raw.zelda_<name>. Returns row count."""

    logger.info("=== Running extractor for '%s' ===", name)

    try:
        records = fetch_all(url)
        loaded, unidentified = load_to_raw(name, records)
        logger.info(
            "[%s] sumary: fetched=%d, loaded=%d, unidentified=%d",
            name, len(records), loaded, unidentified
        )
        return loaded, unidentified
        
    except Exception:
        logger.exception("[%s] extractor failed", name)
        raise