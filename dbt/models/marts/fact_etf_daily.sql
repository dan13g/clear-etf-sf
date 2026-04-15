select
    prices.date_key,
    etf.asset_key as etf_key,
    risk.close_price,
    risk.return_1d,
    risk.return_1w,
    risk.return_1m,
    risk.return_3m,
    risk.return_6m,
    risk.return_1y,
    risk.volatility_30d,
    risk.drawdown_52w,
    risk.sharpe_proxy_1y as sharpe_proxy
from {{ ref('int_asset_risk_enriched') }} as risk
inner join {{ ref('stg_asset_prices') }} as prices
    on risk.asset_key = prices.asset_key
   and risk.full_date = prices.full_date
inner join {{ ref('dim_etf_profile') }} as etf
    on risk.asset_key = etf.asset_key
