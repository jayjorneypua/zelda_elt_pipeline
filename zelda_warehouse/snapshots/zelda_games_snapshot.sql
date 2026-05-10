{% snapshot zelda_games_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'description', 'developer', 'publisher', 'released_date']
    )
}}

select
    payload->>'id'              as id,
    payload->>'name'            as name,
    payload->>'description'     as description,
    payload->>'developer'       as developer,
    payload->>'publisher'       as publisher,
    payload->>'released_date'   as released_date
from 
    {{ source('zelda_raw', 'zelda_games') }}

{% endsnapshot %}