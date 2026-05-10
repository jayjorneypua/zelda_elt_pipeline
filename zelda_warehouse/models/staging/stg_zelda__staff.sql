-- One row per staff member, fields parsed out of the JSON payload.
-- 1:1 with raw.zelda_staff — same grain, just typed/renamed.

-- payload is the column name
-- ->> postgre operator that extracts a text value from a JSON object
-- 'id' is the key in the JSON object that we want to extract

-- ->> returns value as text
-- -> returns value as JSON

select
    trim(payload->>'id')          as staff_id,
    trim(payload->>'name')        as staff_name,
    payload->'worked_on'          as worked_on_games,
    extracted_at::timestamptz     as extracted_at
from
    {{ source('zelda_raw', 'zelda_staff') }}