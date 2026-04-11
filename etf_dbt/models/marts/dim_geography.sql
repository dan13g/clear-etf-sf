with geographies as (
    select distinct
        geography_name
    from {{ ref('stg_geography') }}
)
select
    md5(lower(geography_name)) as geography_key,
    geography_name,
    case
        when geography_name = 'US' then 'North America'
        when geography_name = 'UK' then 'Europe'
        when geography_name = 'Developed ex-US' then 'Developed Markets'
        when lower(geography_name) like '%emerging%' then 'Emerging Markets'
        else 'Other'
    end as geography_group
from geographies
