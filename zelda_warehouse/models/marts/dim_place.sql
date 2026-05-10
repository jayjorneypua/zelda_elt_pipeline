select
    dbt_scd_id              as place_sk,
    id                      as place_id,
    name                    as place_name,
    description             as place_description,
    dbt_valid_from          as valid_from,
    dbt_valid_to            as valid_to,
    dbt_valid_to is null    as is_current
from 
    {{ ref('zelda_places_snapshot') }}