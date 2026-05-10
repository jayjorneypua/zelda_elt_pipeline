select
    dim_dungeon.dungeon_sk,
    intermediate_dungeon_appearances.dungeon_id,
    dim_dungeon.dungeon_name,
    dim_dungeon.dungeon_description,
    dim_game.game_sk,
    intermediate_dungeon_appearances.game_id,
    dim_game.game_name,
    dim_game.released_date
from
    {{ ref('int_zelda__dungeons_appearances_unnested') }} intermediate_dungeon_appearances
left join
    {{ ref('dim_dungeon') }} dim_dungeon
        on dim_dungeon.dungeon_id = intermediate_dungeon_appearances.dungeon_id
left join
    {{ ref('dim_game') }} dim_game
        on dim_game.game_id = intermediate_dungeon_appearances.game_id