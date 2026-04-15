select
    asset_key,
    ticker,
    date_key,
    full_date,
    stddev_samp(daily_return) over (
        partition by asset_key
        order by full_date
        rows between 29 preceding and current row
    ) * sqrt(252) as volatility_30d,
    stddev_samp(daily_return) over (
        partition by asset_key
        order by full_date
        rows between 89 preceding and current row
    ) * sqrt(252) as volatility_90d,
    (
        avg(daily_return) over (
            partition by asset_key
            order by full_date
            rows between 251 preceding and current row
        )
        / nullif(
            stddev_samp(daily_return) over (
                partition by asset_key
                order by full_date
                rows between 251 preceding and current row
            ),
            0
        )
    ) * sqrt(252) as sharpe_proxy_1y
from {{ ref('int_asset_returns') }}
