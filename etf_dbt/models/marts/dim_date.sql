with bounds as (
    select
        min(trading_date) as min_date,
        max(trading_date) as max_date
    from {{ ref('stg_yfinance') }}
),
date_spine as (
    select
        full_date
    from bounds,
    generate_series(min_date, max_date, interval 1 day) as t(full_date)
),
trading_days as (
    select distinct
        trading_date
    from {{ ref('stg_yfinance') }}
)
select
    cast(strftime(full_date, '%Y%m%d') as bigint) as date_key,
    full_date,
    extract(day from full_date) as day_of_month,
    strftime(full_date, '%A') as day_name,
    extract(week from full_date) as week_of_year,
    extract(month from full_date) as month_number,
    strftime(full_date, '%B') as month_name,
    extract(quarter from full_date) as quarter_number,
    extract(year from full_date) as year_number,
    full_date = last_day(full_date) as month_end_flag,
    full_date = cast(date_trunc('quarter', full_date) + interval 3 month - interval 1 day as date) as quarter_end_flag,
    full_date = cast(date_trunc('year', full_date) + interval 1 year - interval 1 day as date) as year_end_flag,
    trading_days.trading_date is not null as trading_day_flag
from date_spine
left join trading_days
    on date_spine.full_date = trading_days.trading_date
order by full_date
