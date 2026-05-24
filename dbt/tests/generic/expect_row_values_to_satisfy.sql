{% test expect_row_values_to_satisfy(model, expression, row_condition=None) %}

select *
from {{ model }}
where
    {% if row_condition %}
    ({{ row_condition }})
    and
    {% endif %}
    not ({{ expression }})

{% endtest %}
