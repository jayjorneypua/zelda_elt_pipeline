select
    b.boss_sk,
    f.boss_id,
    b.boss_name,
    d.dungeon_sk,
    f.dungeon_id,
    d.dungeon_name
from 
    {{ ref('int_zelda__boss_dungeons_unnested') }} f
left join 
    {{ ref('dim_boss') }} b
        on b.boss_id    = f.boss_id    and b.is_current
left join 
    {{ ref('dim_dungeon') }} d 
        on d.dungeon_id = f.dungeon_id and d.is_current