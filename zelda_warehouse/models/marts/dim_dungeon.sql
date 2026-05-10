select
    dbt_scd_id           as dungeon_sk,
    id                   as dungeon_id,
    name                 as dungeon_name,
    description          as dungeon_description,
    dbt_valid_from       as valid_from,
    dbt_valid_to         as valid_to,
    dbt_valid_to is null as is_current
from 
    {{ ref('zelda_dungeons_snapshot') }}