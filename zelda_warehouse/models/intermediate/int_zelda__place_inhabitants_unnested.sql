select
    place.place_id                             as place_id,
    d.value::text                              as inhabitant_url,
    {{ extract_id_from_url('d.value::text') }} as inhabitant_id
from 
    {{ ref('stg_zelda__places') }} place,
     jsonb_array_elements_text(place.inhabitants) as d(value)