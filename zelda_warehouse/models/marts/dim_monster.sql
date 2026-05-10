select
    dbt_scd_id              as monster_sk,
    id                      as monster_id,
    name                    as monster_name,
    description             as monster_description,
    dbt_valid_from          as valid_from,
    dbt_valid_to            as valid_to,
    dbt_valid_to is null    as is_current
    
from 
    {{ ref('zelda_monsters_snapshot') }}