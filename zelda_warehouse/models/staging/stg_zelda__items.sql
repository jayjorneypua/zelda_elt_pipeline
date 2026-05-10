select
    trim(payload->>'id')           as item_id,
    trim(payload->>'name')         as item_name,
    trim(payload->>'description')  as description,
    payload->'games'               as games,
    extracted_at
from 
    {{ source('zelda_raw', 'zelda_items') }}