
select
    trim(payload->>'id')            as place_id,
    trim(payload->>'name')          as place_name,
    trim(payload->>'description')   as description,
    payload->'appearances'          as appearances_games,
    payload->'inhabitants'          as inhabitants,
    extracted_at::timestamptz       as extracted_at
from
    {{ source('zelda_raw', 'zelda_places') }}