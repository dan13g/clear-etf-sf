select
    trend.date_key,
    trend.full_date,
    asset.asset_key,
    asset.ticker,
    asset.asset_name,
    asset.asset_type,
    asset.asset_subtype,
    asset.region,
    trend.price_for_returns,
    trend.sma_20,
    trend.sma_50,
    trend.sma_200,
    trend.above_sma_50_flag,
    trend.above_sma_200_flag,
    trend.trend_score,
    trend.trend_label
from {{ ref('int_asset_trend_inputs') }} as trend
inner join {{ ref('dim_asset') }} as asset
    on trend.asset_key = asset.asset_key
