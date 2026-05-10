select
    boss.boss_id,
    a.value::text                              as game_url,
    {{ extract_id_from_url('a.value::text') }} as game_id
from
    {{ ref('stg_zelda__bosses') }} boss,
        jsonb_array_elements_text(boss.appearances_games) as a(value)