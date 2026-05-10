{% snapshot zelda_staff_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='id',
      strategy='check',
      check_cols=['name', 'worked_on']
    )
}}

select
    payload->>'id'        as id,
    payload->>'name'      as name,
    payload->'worked_on'  as worked_on
from {{ source('zelda_raw', 'zelda_staff') }}

{% endsnapshot %}