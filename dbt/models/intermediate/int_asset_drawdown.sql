select
    asset_key,
    ticker,
    date_key,
    full_date,
    price_for_returns,
    max(price_for_returns) over (
        partition by asset_key
        order by full_date
        rows between 251 preceding and current row
    ) as rolling_peak_252d,
    case
        when max(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between 251 preceding and current row
        ) = 0 then null
        else price_for_returns / max(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between 251 preceding and current row
        ) - 1
    end as drawdown_52w,
    case
        when max(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between unbounded preceding and current row
        ) = 0 then null
        else price_for_returns / max(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between unbounded preceding and current row
        ) - 1
    end as drawdown_since_inception
from {{ ref('int_asset_returns') }}
