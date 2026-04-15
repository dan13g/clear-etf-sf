select
    left_returns.full_date,
    left_returns.date_key,
    left_returns.asset_key,
    left_returns.ticker,
    right_returns.asset_key as compare_asset_key,
    right_returns.ticker as compare_ticker,
    left_returns.daily_return,
    right_returns.daily_return as compare_daily_return
from {{ ref('int_asset_returns') }} as left_returns
inner join {{ ref('int_asset_returns') }} as right_returns
    on left_returns.full_date = right_returns.full_date
   and left_returns.asset_key < right_returns.asset_key
where left_returns.daily_return is not null
  and right_returns.daily_return is not null
