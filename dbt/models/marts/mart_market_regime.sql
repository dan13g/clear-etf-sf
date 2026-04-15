with daily_signals as (
    select
        returns.full_date,
        max(case when returns.ticker = '^GSPC' then returns.return_1m end) as sp500_return_1m,
        max(case when returns.ticker = 'AGGG.L' then returns.return_1m end) as global_bond_return_1m,
        max(case when returns.ticker = 'GC=F' then returns.return_1m end) as gold_return_1m,
        max(case when returns.ticker = 'CL=F' then returns.return_1m end) as oil_return_1m,
        max(case when returns.ticker = 'GBPUSD=X' then returns.return_1m end) as gbpusd_return_1m,
        max(case when trend.ticker = '^GSPC' then trend.above_sma_200_flag end) as sp500_above_sma_200_flag,
        avg(case when asset.asset_type in ('ETF', 'Stock', 'Index') then returns.return_1d end) as growth_asset_avg_return_1d
    from {{ ref('mart_asset_returns') }} as returns
    inner join {{ ref('dim_asset') }} as asset
        on returns.asset_key = asset.asset_key
    left join {{ ref('mart_asset_trend') }} as trend
        on returns.asset_key = trend.asset_key
       and returns.full_date = trend.full_date
    group by 1
)
select
    cast(strftime(full_date, '%Y%m%d') as bigint) as date_key,
    full_date,
    sp500_return_1m,
    global_bond_return_1m,
    gold_return_1m,
    oil_return_1m,
    gbpusd_return_1m,
    sp500_above_sma_200_flag,
    growth_asset_avg_return_1d,
    case
        when sp500_return_1m > 0 and coalesce(sp500_above_sma_200_flag, false) and coalesce(global_bond_return_1m, 0) >= 0 then 'Risk On'
        when sp500_return_1m < 0 and coalesce(global_bond_return_1m, 0) > 0 then 'Defensive'
        when coalesce(oil_return_1m, 0) > 0 and coalesce(gold_return_1m, 0) > 0 and coalesce(global_bond_return_1m, 0) < 0 then 'Inflationary'
        else 'Mixed'
    end as regime_label
from daily_signals
