with typed_prices as (
    select
        cast(raw.date as date) as full_date,
        upper(cast(raw.ticker as varchar)) as ticker,
        case
            when cast(raw.open as double) > 0 then cast(raw.open as double)
        end as open_price,
        case
            when cast(raw.high as double) > 0 then cast(raw.high as double)
        end as reported_high_price,
        case
            when cast(raw.low as double) > 0 then cast(raw.low as double)
        end as reported_low_price,
        case
            when cast(raw.close as double) > 0 then cast(raw.close as double)
        end as close_price,
        case
            when cast(raw.adj_close as double) > 0 then cast(raw.adj_close as double)
        end as adj_close_price,
        cast(raw.volume as double) as volume
    from {{ source('snowflake_raw', 'asset_prices_yfinance') }} as raw
    where cast(raw.date as date) is not null
)

select
    to_number(to_char(prices.full_date, 'YYYYMMDD')) as date_key,
    prices.full_date,
    asset.asset_key,
    asset.ticker,
    asset.asset_name,
    asset.asset_type,
    asset.asset_subtype,
    asset.region,
    asset.country,
    asset.currency,
    asset.exchange,
    prices.open_price,
    -- yfinance occasionally emits daily high/low values that do not bracket
    -- the reported open/close; normalize the range while preserving raw close.
    greatest_ignore_nulls(
        prices.reported_high_price,
        prices.reported_low_price,
        prices.open_price,
        prices.close_price
    ) as high_price,
    least_ignore_nulls(
        prices.reported_low_price,
        prices.reported_high_price,
        prices.open_price,
        prices.close_price
    ) as low_price,
    prices.close_price,
    prices.adj_close_price,
    coalesce(prices.adj_close_price, prices.close_price) as price_for_returns,
    prices.volume
from typed_prices as prices
inner join {{ ref('stg_asset_master') }} as asset
    on prices.ticker = asset.ticker
where prices.close_price is not null
