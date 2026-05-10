select
    place.place_sk,
    f.place_id,
    place.place_name,
    character.character_sk,
    f.inhabitant_id,
    character.character_name
from 
    {{ ref('int_zelda__place_inhabitants_unnested') }} f
left join 
    {{ ref('dim_place') }} place
        on place.place_id = f.place_id and place.is_current
left join 
    {{ ref('dim_character') }} character 
        on character.character_id = f.inhabitant_id and character.is_current