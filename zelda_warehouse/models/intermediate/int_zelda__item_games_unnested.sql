select
    s.item_id,
    g.value::text                               as game_url,
    {{ extract_id_from_url('g.value::text') }}  as game_id
from
    {{ ref('stg_zelda__items') }} s,
    jsonb_array_elements_text(s.games) as g(value)    