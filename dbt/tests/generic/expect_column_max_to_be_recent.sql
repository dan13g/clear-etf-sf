{% test expect_column_max_to_be_recent(model, column_name, max_age_days) %}

select
    max({{ column_name }}) as max_value
from {{ model }}
having max({{ column_name }}) < dateadd(day, -{{ max_age_days }}, current_date)

{% endtest %}
