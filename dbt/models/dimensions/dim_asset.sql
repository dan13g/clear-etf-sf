with price_bounds as (
    select
        asset_key,
        min(full_date) as first_seen_date,
        max(full_date) as last_seen_date
    from {{ ref('stg_asset_prices') }}
    group by 1
)
select
    asset.asset_key,
    asset.ticker,
    asset.asset_name,
    asset.asset_type,
    asset.asset_subtype,
    asset.region,
    asset.country,
    asset.currency,
    asset.provider_name,
    asset.exchange,
    asset.is_active,
    bounds.first_seen_date,
    bounds.last_seen_date
from {{ ref('stg_asset_master') }} as asset
left join price_bounds as bounds
    on asset.asset_key = bounds.asset_key
