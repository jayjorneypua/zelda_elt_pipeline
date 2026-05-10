select
    dbt_scd_id           as character_sk,
    id                   as character_id,
    name                 as character_name,
    description,
    gender,
    race,
    dbt_valid_from       as valid_from,
    dbt_valid_to         as valid_to,
    dbt_valid_to is null as is_current
from 
    {{ ref('zelda_characters_snapshot') }}