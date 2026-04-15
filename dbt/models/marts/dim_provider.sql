with providers as (
    select distinct
        provider_name
    from {{ ref('dim_etf_profile') }}
    where provider_name is not null
)
select
    md5(lower(provider_name)) as provider_key,
    provider_name,
    provider_name as provider_group,
    cast(null as varchar) as provider_country
from providers
