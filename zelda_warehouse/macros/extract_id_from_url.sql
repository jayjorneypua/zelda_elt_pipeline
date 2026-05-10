{% macro extract_id_from_url(url_column) %}
    split_part({{ url_column }}, '/', -1)
{% endmacro %}