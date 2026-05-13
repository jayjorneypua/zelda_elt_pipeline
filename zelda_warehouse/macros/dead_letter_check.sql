{% macro dead_letter_check(source_name, source_table, required_text_fields=['id', 'name']) %}
    select
        '{{ source_name }}'    as source_name,
        payload->>'id'         as natural_key,
        payload                as raw_payload,
        extracted_at,
        case
            {% for field in required_text_fields %}
            when payload->>'{{ field }}' is null
                then 'missing_{{ field }}'
            when trim(payload->>'{{ field }}') = ''
                then 'empty_{{ field }}'
            {% endfor %}
            else 'unknown'
        end                    as error_type
    from 
        {{ source('zelda_raw', source_table) }}
    where
        {% for field in required_text_fields %}
            payload->>'{{ field }}' is null
            or trim(payload->>'{{ field }}') = ''
            {% if not loop.last %} or {% endif %}
        {% endfor %}
{% endmacro %}