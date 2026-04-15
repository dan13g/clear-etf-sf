with ordered_returns as (
    select
        *,
        row_number() over (
            partition by asset_key, compare_asset_key
            order by full_date desc
        ) as reverse_row_num
    from {{ ref('int_asset_pair_returns') }}
),
windowed as (
    select *
    from ordered_returns
    where reverse_row_num <= 90
)
select
    asset_key,
    ticker,
    compare_asset_key,
    compare_ticker,
    max(full_date) as as_of_date,
    count(*) as observation_count,
    corr(daily_return, compare_daily_return) as correlation_90d
from windowed
group by 1, 2, 3, 4
