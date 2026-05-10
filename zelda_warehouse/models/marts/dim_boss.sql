select
    dbt_scd_id              as boss_sk,
    id                      as boss_id,
    name                    as boss_name,
    description             as boss_description,
    dbt_valid_from          as valid_from,
    dbt_valid_to            as valid_to,
    dbt_valid_to is null    as is_current
from 
    {{ ref('zelda_bosses_snapshot') }}