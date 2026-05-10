

select
    trim(payload->>'id')   as game_id,
    trim(payload->>'name') as game_name,
    trim(payload->>'description') as description,
    trim(payload->>'developer') as developer,
    trim(payload->>'publisher') as publisher,
    case
        when payload->>'released_date' ~ '^\s*[A-Za-z]+ \d{1,2}, \d{4}\s*$'
            then to_date(trim(payload->>'released_date'), 'FMMonth DD, YYYY')
        else null
    end as released_date,
    extracted_at::timestamptz as extracted_at
from
    {{ source('zelda_raw', 'zelda_games') }}