with lagged_prices as (
    select
        asset_key,
        ticker,
        date_key,
        full_date,
        close_price,
        adj_close_price,
        price_for_returns,
        lag(price_for_returns) over (
            partition by asset_key order by full_date
        ) as lag_price_1d,
        lag(price_for_returns, 5) over (
            partition by asset_key order by full_date
        ) as lag_price_1w,
        lag(price_for_returns, 21) over (
            partition by asset_key order by full_date
        ) as lag_price_1m,
        lag(price_for_returns, 63) over (
            partition by asset_key order by full_date
        ) as lag_price_3m,
        lag(price_for_returns, 126) over (
            partition by asset_key order by full_date
        ) as lag_price_6m,
        lag(price_for_returns, 252) over (
            partition by asset_key order by full_date
        ) as lag_price_1y
    from {{ ref('stg_asset_prices') }}
),
base_prices as (
    select
        asset_key,
        ticker,
        date_key,
        full_date,
        close_price,
        adj_close_price,
        price_for_returns,
        case
            when lag_price_1d is null or lag_price_1d = 0 then null
            else price_for_returns / lag_price_1d - 1
        end as daily_return,
        case
            when lag_price_1d is null or lag_price_1d = 0 then null
            else price_for_returns / lag_price_1d - 1
        end as return_1d,
        case
            when lag_price_1w is null or lag_price_1w = 0 then null
            else price_for_returns / lag_price_1w - 1
        end as return_1w,
        case
            when lag_price_1m is null or lag_price_1m = 0 then null
            else price_for_returns / lag_price_1m - 1
        end as return_1m,
        case
            when lag_price_3m is null or lag_price_3m = 0 then null
            else price_for_returns / lag_price_3m - 1
        end as return_3m,
        case
            when lag_price_6m is null or lag_price_6m = 0 then null
            else price_for_returns / lag_price_6m - 1
        end as return_6m,
        case
            when lag_price_1y is null or lag_price_1y = 0 then null
            else price_for_returns / lag_price_1y - 1
        end as return_1y
    from lagged_prices
)
select * from base_prices
