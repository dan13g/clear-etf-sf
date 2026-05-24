with recursive
bounds as (
    select
        min(full_date) as min_date,
        max(full_date) as max_date
    from {{ ref('stg_asset_prices') }}
),
date_spine(full_date, max_date) as (
    select
        min_date,
        max_date
    from bounds

    union all

    select
        cast(dateadd(day, 1, full_date) as date),
        max_date
    from date_spine
    where full_date < max_date
),
trading_days as (
    select distinct
        full_date
    from {{ ref('stg_asset_prices') }}
)
select
    to_number(to_char(date_spine.full_date, 'YYYYMMDD')) as date_key,
    date_spine.full_date as full_date,
    trim(to_char(date_spine.full_date, 'DAY')) as day_name,
    extract(day from date_spine.full_date) as day_of_month,
    extract(week from date_spine.full_date) as week_of_year,
    extract(month from date_spine.full_date) as month_number,
    trim(to_char(date_spine.full_date, 'MONTH')) as month_name,
    extract(quarter from date_spine.full_date) as quarter_number,
    extract(year from date_spine.full_date) as year_number,
    date_spine.full_date = last_day(date_spine.full_date) as month_end_flag,
    date_spine.full_date = last_day(date_spine.full_date, 'quarter') as quarter_end_flag,
    date_spine.full_date = last_day(date_spine.full_date, 'year') as year_end_flag,
    trading_days.full_date is not null as trading_day_flag
from date_spine
left join trading_days
    on date_spine.full_date = trading_days.full_date
order by date_spine.full_date
