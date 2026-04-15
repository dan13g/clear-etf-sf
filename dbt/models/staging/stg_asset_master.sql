select
    upper(nullif(trim(ticker), '')) as ticker,
    nullif(trim(asset_name), '') as asset_name,
    nullif(trim(asset_type), '') as asset_type,
    nullif(trim(asset_subtype), '') as asset_subtype,
    nullif(trim(region), '') as region,
    nullif(trim(country), '') as country,
    nullif(trim(currency), '') as currency,
    nullif(trim(provider_name), '') as provider_name,
    nullif(trim(exchange), '') as exchange,
    coalesce(is_active, true) as is_active
from {{ ref('raw_asset_master') }}
where nullif(trim(ticker), '') is not null
