select
    trim(payload->>'id')           as character_id,
    trim(payload->>'name')         as character_name,
    trim(payload->>'description')  as description,
    trim(payload->>'gender')       as gender,
    trim(payload->>'race')         as race,
    payload->'appearances'         as appearances_games,
    extracted_at
from 
    {{ source('zelda_raw', 'zelda_characters') }}