with game_ids as (
    select id from {{ source('zelda_raw', 'zelda_games') }}
)

{{ dead_letter_check('staff',      'zelda_staff',      ['id', 'name']) }}
union all
{{ dead_letter_check('games',      'zelda_games',      ['id', 'name']) }}
union all
{{ dead_letter_check('characters', 'zelda_characters', ['id', 'name']) }}
union all
{{ dead_letter_check('monsters',   'zelda_monsters',   ['id', 'name']) }}
union all
{{ dead_letter_check('dungeons',   'zelda_dungeons',   ['id', 'name']) }}
union all
{{ dead_letter_check('bosses',     'zelda_bosses',     ['id', 'name']) }}
union all
{{ dead_letter_check('places',     'zelda_places',     ['id', 'name']) }}
union all
{{ dead_letter_check('items',      'zelda_items',      ['id', 'name']) }}

union all

{{ dead_letter_check_links('staff',      'zelda_staff',      'worked_on') }}
union all
{{ dead_letter_check_links('characters', 'zelda_characters', 'appearances') }}
union all
{{ dead_letter_check_links('monsters',   'zelda_monsters',   'appearances') }}
union all
{{ dead_letter_check_links('bosses',     'zelda_bosses',     'appearances') }}
union all
{{ dead_letter_check_links('dungeons',   'zelda_dungeons',   'appearances') }}
union all
{{ dead_letter_check_links('places',     'zelda_places',     'appearances') }}
union all
{{ dead_letter_check_links('items',      'zelda_items',      'games') }}

union all

select
    source_name,
    null                                as natural_key,
    raw_payload,
    extracted_at,
    coalesce(reason, 'unidentified')    as error_type
from
    {{ source('zelda_raw', 'unidentified') }}
