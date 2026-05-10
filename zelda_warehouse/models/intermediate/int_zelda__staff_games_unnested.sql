-- Explode the worked_on array. One row per (staff, game) pair.
-- Grain has changed from staging, which is why this lives in intermediate.

select
    s.staff_id,
    g.value::text                               as game_url,
    {{ extract_id_from_url('g.value::text') }}  as game_id
from
    {{ ref('stg_zelda__staff') }} s,
    jsonb_array_elements_text(s.worked_on_games) as g(value)    