select
    c.monster_id,
    a.value::text                              as game_url,
    {{ extract_id_from_url('a.value::text') }} as game_id
from 
    {{ ref('stg_zelda__monsters') }} c,
     jsonb_array_elements_text(c.appearances_monster) as a(value)