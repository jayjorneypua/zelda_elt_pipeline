select
    dbt_scd_id                                                             as game_sk,
    id                                                                     as game_id,
    name                                                                   as game_name,
    description,
    developer,
    publisher,
    case
        when released_date ~ '^\s*[A-Za-z]+ \d{1,2}, \d{4}\s*$'
            then to_date(trim(released_date), 'FMMonth DD, YYYY')
        else null
    end                                                                    as released_date,
    dbt_valid_from                                                         as valid_from,
    dbt_valid_to                                                           as valid_to,
    dbt_valid_to is null                                                   as is_current
from 
    {{ ref('zelda_games_snapshot') }}