
select
    trim(payload->>'id')           as dungeon_id,
    trim(payload->>'name')         as dungeon_name,
    trim(payload->>'description')  as description,
    payload->'appearances'         as appearances_dungeon,
    extracted_at::timestamptz      as extracted_at
from
    {{ source('zelda_raw', 'zelda_dungeons') }}