select
    place.place_sk,
    f.place_id,
    place.place_name,
    game.game_sk,
    f.game_id,
    game.game_name
from 
    {{ ref('int_zelda__place_appearances_unnested') }} f
left join 
    {{ ref('dim_place') }} place
        on place.place_id = f.place_id and place.is_current
left join 
    {{ ref('dim_game') }} game 
        on game.game_id = f.game_id and game.is_current