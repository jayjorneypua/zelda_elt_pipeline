select
    c.character_sk,
    f.character_id,
    c.character_name,
    g.game_sk,
    f.game_id,
    g.game_name,
    g.released_date
from 
    {{ ref('int_zelda__character_appearances_unnested') }} f
left join 
    {{ ref('dim_character') }} c 
        on c.character_id = f.character_id
left join 
    {{ ref('dim_game') }} g 
        on g.game_id      = f.game_id