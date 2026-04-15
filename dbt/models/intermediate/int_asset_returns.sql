with base_prices as (
    select
        asset_key,
        ticker,
        date_key,
        full_date,
        close_price,
        adj_close_price,
        price_for_returns,
        case
            when lag(price_for_returns) over w is null or lag(price_for_returns) over w = 0 then null
            else price_for_returns / lag(price_for_returns) over w - 1
        end as daily_return,
        case
            when lag(price_for_returns) over w is null or lag(price_for_returns) over w = 0 then null
            else price_for_returns / lag(price_for_returns) over w - 1
        end as return_1d,
        case
            when lag(price_for_returns, 5) over w is null or lag(price_for_returns, 5) over w = 0 then null
            else price_for_returns / lag(price_for_returns, 5) over w - 1
        end as return_1w,
        case
            when lag(price_for_returns, 21) over w is null or lag(price_for_returns, 21) over w = 0 then null
            else price_for_returns / lag(price_for_returns, 21) over w - 1
        end as return_1m,
        case
            when lag(price_for_returns, 63) over w is null or lag(price_for_returns, 63) over w = 0 then null
            else price_for_returns / lag(price_for_returns, 63) over w - 1
        end as return_3m,
        case
            when lag(price_for_returns, 126) over w is null or lag(price_for_returns, 126) over w = 0 then null
            else price_for_returns / lag(price_for_returns, 126) over w - 1
        end as return_6m,
        case
            when lag(price_for_returns, 252) over w is null or lag(price_for_returns, 252) over w = 0 then null
            else price_for_returns / lag(price_for_returns, 252) over w - 1
        end as return_1y
    from {{ ref('stg_asset_prices') }}
    window w as (partition by asset_key order by full_date)
)
select * from base_prices
