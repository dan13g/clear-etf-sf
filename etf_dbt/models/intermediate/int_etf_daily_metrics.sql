with daily_returns as (
    select
        ticker,
        trading_date,
        close_price,
        case
            when lag(close_price) over w is null or lag(close_price) over w = 0 then null
            else close_price / lag(close_price) over w - 1
        end as return_1d,
        case
            when lag(close_price, 5) over w is null or lag(close_price, 5) over w = 0 then null
            else close_price / lag(close_price, 5) over w - 1
        end as return_1w,
        case
            when lag(close_price, 21) over w is null or lag(close_price, 21) over w = 0 then null
            else close_price / lag(close_price, 21) over w - 1
        end as return_1m,
        case
            when lag(close_price, 63) over w is null or lag(close_price, 63) over w = 0 then null
            else close_price / lag(close_price, 63) over w - 1
        end as return_3m,
        case
            when lag(close_price, 126) over w is null or lag(close_price, 126) over w = 0 then null
            else close_price / lag(close_price, 126) over w - 1
        end as return_6m,
        case
            when lag(close_price, 252) over w is null or lag(close_price, 252) over w = 0 then null
            else close_price / lag(close_price, 252) over w - 1
        end as return_1y,
        case
            when lag(close_price) over w is null or lag(close_price) over w = 0 then null
            else close_price / lag(close_price) over w - 1
        end as daily_return
    from {{ ref('stg_yfinance') }}
    window w as (partition by ticker order by trading_date)
),
metrics as (
    select
        ticker,
        trading_date,
        close_price,
        return_1d,
        return_1w,
        return_1m,
        return_3m,
        return_6m,
        return_1y,
        stddev_samp(daily_return) over (
            partition by ticker
            order by trading_date
            rows between 29 preceding and current row
        ) * sqrt(252) as volatility_30d,
        case
            when max(close_price) over (
                partition by ticker
                order by trading_date
                rows between 251 preceding and current row
            ) = 0 then null
            else close_price / max(close_price) over (
                partition by ticker
                order by trading_date
                rows between 251 preceding and current row
            ) - 1
        end as drawdown_52w,
        (
            avg(daily_return) over (
                partition by ticker
                order by trading_date
                rows between 251 preceding and current row
            )
            / nullif(
                stddev_samp(daily_return) over (
                    partition by ticker
                    order by trading_date
                    rows between 251 preceding and current row
                ),
                0
            )
        ) * sqrt(252) as sharpe_proxy
    from daily_returns
)
select * from metrics
