{% snapshot zelda_characters_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'description', 'gender', 'race', 'appearances']
    )
}}

select
    payload->>'id'          as id,
    payload->>'name'        as name,
    payload->>'description' as description,
    payload->>'gender'      as gender,
    payload->>'race'        as race,
    payload->'appearances'  as appearances
from 
    {{ source('zelda_raw', 'zelda_characters') }}

{% endsnapshot %}