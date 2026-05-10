
select
    trim(payload->>'id')            as boss_id,
    trim(payload->>'name')          as boss_name,
    trim(payload->>'description')   as description,
    payload->'appearances'          as appearances_games,
    payload->'dungeons'             as dungeons,
    extracted_at::timestamptz       as extracted_at
from
    {{ source('zelda_raw', 'zelda_bosses') }}