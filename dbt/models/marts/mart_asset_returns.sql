select
    returns.date_key,
    returns.full_date,
    asset.asset_key,
    asset.ticker,
    asset.asset_name,
    asset.asset_type,
    asset.asset_subtype,
    asset.region,
    asset.country,
    asset.currency,
    returns.close_price,
    returns.adj_close_price,
    returns.price_for_returns,
    returns.return_1d,
    returns.return_1w,
    returns.return_1m,
    returns.return_3m,
    returns.return_6m,
    returns.return_1y,
    returns.daily_return
from {{ ref('int_asset_returns') }} as returns
inner join {{ ref('dim_asset') }} as asset
    on returns.asset_key = asset.asset_key
