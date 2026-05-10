{% snapshot zelda_places_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'description', 'appearances', 'inhabitants']
    )
}}

select
    payload->>'id'           as id,
    payload->>'name'         as name,
    payload->>'description'  as description,
    payload->'appearances'   as appearances,
    payload->'inhabitants'   as inhabitants
from 
    {{ source('zelda_raw', 'zelda_places') }}

{% endsnapshot %}