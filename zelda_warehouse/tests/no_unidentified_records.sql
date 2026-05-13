
select 
    count(*) as bad_count
from 
    {{ ref('int_dead_letters') }}
where 
    error_type in ('missing_id', 'not_a_dict')
having 
    count(*) > 0