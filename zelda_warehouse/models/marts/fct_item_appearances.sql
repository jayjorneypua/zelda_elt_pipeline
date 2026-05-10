select
    item.item_sk,
    f.item_id,
    item.item_name,
    game.game_sk,
    f.game_id,
    game.game_name,
    game.released_date
from 
    {{ ref('int_zelda__item_games_unnested') }} f
left join 
    {{ ref('dim_item') }} item
        on item.item_id = f.item_id
left join 
    {{ ref('dim_game')  }} game
        on game.game_id  = f.game_id