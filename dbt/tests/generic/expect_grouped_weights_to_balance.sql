{% test expect_grouped_weights_to_balance(
    model,
    group_by,
    weight_column,
    fraction_min=0.99,
    fraction_max=1.01,
    percent_min=99,
    percent_max=101
) %}

with grouped_weights as (
    select
        {{ group_by }} as grouping_key,
        sum({{ weight_column }}) as total_weight
    from {{ model }}
    where {{ weight_column }} is not null
    group by 1
)
select *
from grouped_weights
where not (
    total_weight between {{ fraction_min }} and {{ fraction_max }}
    or total_weight between {{ percent_min }} and {{ percent_max }}
)

{% endtest %}
