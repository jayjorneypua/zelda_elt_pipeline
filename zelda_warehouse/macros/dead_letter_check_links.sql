{% macro dead_letter_check_links(source_name, source_table, link_field) %}

    select distinct
        '{{ source_name }}'                as source_name,
        src.payload->>'id'                 as natural_key,
        src.payload                        as raw_payload,
        src.extracted_at,
        'invalid_{{ link_field }}_link'    as error_type
    from 
        {{ source('zelda_raw', source_table) }} src
    cross join lateral
        jsonb_array_elements_text(src.payload->'{{ link_field }}') as lnk(url)
    left join game_ids g
        on g.id = substring(lnk.url from '[^/]+$')
    where 
        src.payload->'{{ link_field }}' is not null
        and g.id is null

{% endmacro %}
