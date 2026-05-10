select
    s.staff_sk,
    f.staff_id,
    s.staff_name,
    g.game_sk,
    f.game_id,
    g.game_name,
    g.released_date
from 
    {{ ref('int_zelda__staff_games_unnested') }} f
left join 
    {{ ref('dim_staff') }} s 
        on s.staff_id = f.staff_id
left join 
    {{ ref('dim_game')  }} g 
        on g.game_id  = f.game_id