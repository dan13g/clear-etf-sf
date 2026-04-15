select
    corr30.as_of_date,
    asset.ticker,
    asset.asset_name,
    asset.asset_type,
    compare_asset.ticker as compare_ticker,
    compare_asset.asset_name as compare_asset_name,
    compare_asset.asset_type as compare_asset_type,
    corr30.observation_count as observation_count_30d,
    corr30.correlation_30d,
    corr90.observation_count as observation_count_90d,
    corr90.correlation_90d
from {{ ref('int_asset_correlation_30d') }} as corr30
left join {{ ref('int_asset_correlation_90d') }} as corr90
    on corr30.asset_key = corr90.asset_key
   and corr30.compare_asset_key = corr90.compare_asset_key
inner join {{ ref('dim_asset') }} as asset
    on corr30.asset_key = asset.asset_key
inner join {{ ref('dim_asset') }} as compare_asset
    on corr30.compare_asset_key = compare_asset.asset_key
