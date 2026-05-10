
select
    trim(payload->>'id')           as monster_id,
    trim(payload->>'name')         as monster_name,
    trim(payload->>'description')  as description,
    payload->'appearances'         as appearances_monster,
    extracted_at::timestamptz      as extracted_at
from
    {{ source('zelda_raw', 'zelda_monsters') }}