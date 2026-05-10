select
    dbt_scd_id           as item_sk,
    id                   as item_id,
    name                 as item_name,
    description          as item_description,
    dbt_valid_from       as valid_from,
    dbt_valid_to         as valid_to,
    dbt_valid_to is null as is_current
    
from 
    {{ ref('zelda_items_snapshot') }}