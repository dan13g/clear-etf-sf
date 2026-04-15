select
    upper(cast(ticker as varchar)) as ticker,
    cast(asset_name as varchar) as asset_name,
    cast(asset_type as varchar) as asset_type,
    cast(asset_subtype as varchar) as asset_subtype,
    cast(region as varchar) as region,
    cast(country as varchar) as country,
    cast(currency as varchar) as currency,
    cast(provider_name as varchar) as provider_name,
    cast(exchange as varchar) as exchange,
    cast(is_active as boolean) as is_active
from {{ source('motherduck_raw', 'asset_master') }}
