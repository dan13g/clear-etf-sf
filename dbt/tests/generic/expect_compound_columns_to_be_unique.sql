{% test expect_compound_columns_to_be_unique(model, column_list) %}

with validation_errors as (
    select
        {% for column in column_list %}
        {{ column }}{% if not loop.last %}, {% endif %}
        {% endfor %},
        count(*) as row_count
    from {{ model }}
    group by
        {% for column in column_list %}
        {{ column }}{% if not loop.last %}, {% endif %}
        {% endfor %}
    having count(*) > 1
)
select *
from validation_errors

{% endtest %}
