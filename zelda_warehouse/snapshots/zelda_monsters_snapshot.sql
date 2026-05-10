{% snapshot zelda_monsters_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'description', 'appearances']
    )
}}

select
    payload->>'id'          as id,
    payload->>'name'        as name,
    payload->'description'  as description,
    payload->'appearances'  as appearances
from 
    {{ source('zelda_raw', 'zelda_monsters') }}

{% endsnapshot %}