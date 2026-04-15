select
    risk.date_key,
    risk.full_date,
    asset.asset_key,
    asset.ticker,
    asset.asset_name,
    asset.asset_type,
    asset.asset_subtype,
    asset.region,
    asset.currency,
    risk.volatility_30d,
    risk.volatility_90d,
    risk.drawdown_52w,
    risk.drawdown_since_inception,
    risk.sharpe_proxy_1y
from {{ ref('int_asset_risk_enriched') }} as risk
inner join {{ ref('dim_asset') }} as asset
    on risk.asset_key = asset.asset_key
