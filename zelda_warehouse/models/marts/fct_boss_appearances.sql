select
    b.boss_sk,
    f.boss_id,
    b.boss_name,
    g.game_sk,
    f.game_id,
    g.game_name
from 
    {{ ref('int_zelda__boss_appearances_unnested') }} f
left join 
    {{ ref('dim_boss') }} b 
        on b.boss_id = f.boss_id and b.is_current
left join 
    {{ ref('dim_game') }} g 
        on g.game_id = f.game_id and g.is_current