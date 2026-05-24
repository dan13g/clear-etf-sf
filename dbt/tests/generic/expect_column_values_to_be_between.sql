{% test expect_column_values_to_be_between(model, column_name, min_value=None, max_value=None, strictly=False, row_condition=None) %}

select *
from {{ model }}
where {{ column_name }} is not null
  {% if row_condition %}
  and ({{ row_condition }})
  {% endif %}
  and (
    {% if min_value is not none %}
      {{ column_name }} {% if strictly %}<= {% else %}< {% endif %} {{ min_value }}
    {% else %}
      false
    {% endif %}
    {% if max_value is not none %}
      or {{ column_name }} {% if strictly %}>= {% else %}> {% endif %} {{ max_value }}
    {% endif %}
  )

{% endtest %}
