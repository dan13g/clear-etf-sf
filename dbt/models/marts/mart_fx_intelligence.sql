select
    returns.full_date,
    returns.date_key,
    asset.asset_key,
    asset.ticker,
    asset.asset_name,
    split_part(asset.ticker, '=', 1) as fx_pair_code,
    returns.return_1d,
    returns.return_1w,
    returns.return_1m,
    risk.volatility_30d,
    risk.drawdown_52w,
    trend.trend_label,
    trend.above_sma_50_flag,
    trend.above_sma_200_flag
from {{ ref('mart_asset_returns') }} as returns
inner join {{ ref('dim_asset') }} as asset
    on returns.asset_key = asset.asset_key
left join {{ ref('mart_asset_risk') }} as risk
    on returns.asset_key = risk.asset_key
   and returns.full_date = risk.full_date
left join {{ ref('mart_asset_trend') }} as trend
    on returns.asset_key = trend.asset_key
   and returns.full_date = trend.full_date
where asset.asset_type = 'FX'
