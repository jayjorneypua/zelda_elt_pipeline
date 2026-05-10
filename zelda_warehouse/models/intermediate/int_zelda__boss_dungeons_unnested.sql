select
    boss.boss_id,
    d.value::text                              as dungeon_url,
    {{ extract_id_from_url('d.value::text') }} as dungeon_id
from 
    {{ ref('stg_zelda__bosses') }} boss,
     jsonb_array_elements_text(boss.dungeons) as d(value)