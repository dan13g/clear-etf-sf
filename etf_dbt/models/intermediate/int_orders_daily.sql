with daily as (
    select
        agency_slug,
        shop_slug,
        period,
        date(created_at) as order_date,
        sum(subtotal_amount) as daily_revenue
    from {{ ref('stg_orders') }}
    group by 1,2,3,4
)
select
    agency_slug,
    shop_slug,
    period,
    stddev(daily_revenue) / nullif(avg(daily_revenue),0) as revenue_volatility
from daily
group by 1,2,3
