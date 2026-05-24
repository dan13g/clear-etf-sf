select
    md5(upper(nullif(trim(cast(ticker as varchar)), ''))) as asset_key,
    upper(nullif(trim(cast(ticker as varchar)), '')) as ticker,
    nullif(trim(cast(asset_name as varchar)), '') as asset_name,
    case lower(trim(cast(asset_type as varchar)))
        when 'etf' then 'ETF'
        when 'stock' then 'Stock'
        when 'index' then 'Index'
        when 'fx' then 'FX'
        when 'commodity' then 'Commodity'
        when 'bond proxy' then 'Bond Proxy'
        else nullif(trim(cast(asset_type as varchar)), '')
    end as asset_type,
    nullif(trim(cast(asset_subtype as varchar)), '') as asset_subtype,
    nullif(trim(cast(region as varchar)), '') as region,
    nullif(trim(cast(country as varchar)), '') as country,
    nullif(trim(cast(currency as varchar)), '') as currency,
    nullif(trim(cast(provider_name as varchar)), '') as provider_name,
    nullif(trim(cast(exchange as varchar)), '') as exchange,
    coalesce(cast(is_active as boolean), true) as is_active
from {{ source('snowflake_raw', 'asset_master') }}
where nullif(trim(cast(ticker as varchar)), '') is not null
  and coalesce(cast(is_active as boolean), true)
