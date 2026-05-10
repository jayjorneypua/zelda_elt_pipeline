""" Shared logic for all Zelda API extractors. """

import os
import json
import time
import requests
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

load_dotenv()
DSN = os.environ["POSTGRES_DSN"]

PAGE_SIZE = 25
SLEEP = 0.2

DDL = """
    CREATE SCHEMA IF NOT EXISTS raw;
    CREATE TABLE IF NOT EXISTS raw.zelda_{name} (
        id TEXT         PRIMARY KEY,
        payload         JSONB NOT NULL,
        extracted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
"""

UPSERT = """
    INSERT INTO raw.zelda_{name} (id, payload)
    VALUES %s
    ON CONFLICT (id) DO UPDATE SET
        payload         = EXCLUDED.payload,
        extracted_at    = NOW()
    WHERE raw.zelda_{name}.payload IS DISTINCT FROM EXCLUDED.payload;
"""

def fetch_all(url):
    """Paginate the API until we've pulled every record."""
    page = 0
    output = []

    while True:
        response = requests.get(url, params={"page": page, "limit": PAGE_SIZE})

        response.raise_for_status()

        body = response.json()

        # Give me whatever's under the data key in body. If there's no data key at all, give me an empty list instead."
        data = body.get("data", [])

        if not data:
            break

        output.extend(data)

        print(f" page {page}: fetched {len(data)} records (running total: {len(output)})")

        if len(data) < PAGE_SIZE:
            break

        page += 1
        time.sleep(SLEEP)

    return output

def load_to_raw(name, records):
    """Upsert records into raw.zelda_<name>."""

    rows = [(record["id"], json.dumps(record)) for record in records]

    with psycopg2.connect(DSN) as connection, connection.cursor() as cursor:

        cursor.execute(DDL.format(name=name))
        execute_values(cursor, UPSERT.format(name=name), rows)

    return len(rows)

def run(name, url):
    """Pull from URL and load into raw.zelda_<name>. Returns row count."""

    records = fetch_all(url)

    row_count = load_to_raw(name, records)

    print(f"[{name}] pulled {len(records)}, upserted into raw.zelda_{name}")

    return row_count