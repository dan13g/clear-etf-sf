with bounds as (
    select
        min(full_date) as min_date,
        max(full_date) as max_date
    from {{ ref('stg_asset_prices') }}
),
date_spine as (
    select
        full_date
    from bounds,
    generate_series(min_date, max_date, interval 1 day) as t(full_date)
),
trading_days as (
    select distinct
        full_date
    from {{ ref('stg_asset_prices') }}
)
select
    cast(strftime(date_spine.full_date, '%Y%m%d') as bigint) as date_key,
    date_spine.full_date as full_date,
    strftime(date_spine.full_date, '%A') as day_name,
    extract(day from date_spine.full_date) as day_of_month,
    extract(week from date_spine.full_date) as week_of_year,
    extract(month from date_spine.full_date) as month_number,
    strftime(date_spine.full_date, '%B') as month_name,
    extract(quarter from date_spine.full_date) as quarter_number,
    extract(year from date_spine.full_date) as year_number,
    date_spine.full_date = last_day(date_spine.full_date) as month_end_flag,
    date_spine.full_date = cast(date_trunc('quarter', date_spine.full_date) + interval 3 month - interval 1 day as date) as quarter_end_flag,
    date_spine.full_date = cast(date_trunc('year', date_spine.full_date) + interval 1 year - interval 1 day as date) as year_end_flag,
    trading_days.full_date is not null as trading_day_flag
from date_spine
left join trading_days
    on date_spine.full_date = trading_days.full_date
order by date_spine.full_date
