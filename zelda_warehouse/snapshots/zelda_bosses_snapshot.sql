{% snapshot zelda_bosses_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'description', 'appearances', 'dungeons']
    )
}}

select
    payload->>'id'           as id,
    payload->>'name'         as name,
    payload->>'description'  as description,
    payload->'appearances'   as appearances,
    payload->'dungeons'      as dungeons
from {{ source('zelda_raw', 'zelda_bosses') }}

{% endsnapshot %}