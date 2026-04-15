select
    asset_key,
    ticker,
    date_key,
    full_date,
    price_for_returns,
    avg(price_for_returns) over (
        partition by asset_key
        order by full_date
        rows between 19 preceding and current row
    ) as sma_20,
    avg(price_for_returns) over (
        partition by asset_key
        order by full_date
        rows between 49 preceding and current row
    ) as sma_50,
    avg(price_for_returns) over (
        partition by asset_key
        order by full_date
        rows between 199 preceding and current row
    ) as sma_200,
    case
        when price_for_returns > avg(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between 49 preceding and current row
        ) then true
        else false
    end as above_sma_50_flag,
    case
        when price_for_returns > avg(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between 199 preceding and current row
        ) then true
        else false
    end as above_sma_200_flag,
    (
        case
            when price_for_returns > avg(price_for_returns) over (
                partition by asset_key
                order by full_date
                rows between 49 preceding and current row
            ) then 1
            else 0
        end
        +
        case
            when price_for_returns > avg(price_for_returns) over (
                partition by asset_key
                order by full_date
                rows between 199 preceding and current row
            ) then 1
            else 0
        end
    ) as trend_score,
    case
        when price_for_returns > avg(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between 49 preceding and current row
        )
        and price_for_returns > avg(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between 199 preceding and current row
        ) then 'Uptrend'
        when price_for_returns < avg(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between 49 preceding and current row
        )
        and price_for_returns < avg(price_for_returns) over (
            partition by asset_key
            order by full_date
            rows between 199 preceding and current row
        ) then 'Downtrend'
        else 'Mixed'
    end as trend_label
from {{ ref('int_asset_returns') }}
