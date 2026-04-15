select
    cast(strftime(cast(raw.date as date), '%Y%m%d') as bigint) as date_key,
    cast(raw.date as date) as full_date,
    asset.asset_key,
    asset.ticker,
    asset.asset_name,
    asset.asset_type,
    asset.asset_subtype,
    asset.region,
    asset.country,
    asset.currency,
    asset.exchange,
    cast(raw.open as double) as open_price,
    cast(raw.high as double) as high_price,
    cast(raw.low as double) as low_price,
    cast(raw.close as double) as close_price,
    cast(raw.adj_close as double) as adj_close_price,
    coalesce(cast(raw.adj_close as double), cast(raw.close as double)) as price_for_returns,
    cast(raw.volume as double) as volume
from {{ source('motherduck_raw', 'asset_prices_yfinance') }} as raw
inner join {{ ref('stg_asset_master') }} as asset
    on upper(cast(raw.ticker as varchar)) = asset.ticker
where cast(raw.date as date) is not null
