select
    dbt_scd_id           as staff_sk,
    id                   as staff_id,
    name                 as staff_name,
    dbt_valid_from       as valid_from,
    dbt_valid_to         as valid_to,
    dbt_valid_to is null as is_current
    
from 
    {{ ref('zelda_staff_snapshot') }}