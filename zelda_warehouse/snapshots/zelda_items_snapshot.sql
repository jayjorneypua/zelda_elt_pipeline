{% snapshot zelda_items_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'description', 'games']
    )
}}

select
    payload->>'id'          as id,
    payload->>'name'        as name,
    payload->>'description' as description,
    payload->'games'        as games
from {{ source('zelda_raw', 'zelda_items') }}

{% endsnapshot %}   