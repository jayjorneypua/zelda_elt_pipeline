select
    c.monster_sk,
    f.monster_id,
    c.monster_name,
    c.monster_description,
    g.game_sk,
    f.game_id,
    g.game_name,
    g.released_date
from
    {{ ref('int_zelda__monster_appearances_unnested') }} f
left join
    {{ ref('dim_monster') }} c
        on c.monster_id = f.monster_id
left join
    {{ ref('dim_game') }} g
        on g.game_id      = f.game_id