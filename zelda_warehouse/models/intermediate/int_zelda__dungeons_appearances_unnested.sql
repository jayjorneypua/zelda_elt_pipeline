select
    dungeon.dungeon_id,
    a.value::text                              as game_url,
    {{ extract_id_from_url('a.value::text') }} as game_id
from
    {{ ref('stg_zelda__dungeons') }} dungeon,
        jsonb_array_elements_text(dungeon.appearances_dungeon) as a(value)