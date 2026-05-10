select
    c.character_id,
    a.value::text                              as game_url,
    {{ extract_id_from_url('a.value::text') }} as game_id
from 
    {{ ref('stg_zelda__characters') }} c,
     jsonb_array_elements_text(c.appearances_games) as a(value)