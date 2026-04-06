with o as (select * from {{ ref('int_orders_monthly') }}),
v as (select * from {{ ref('int_orders_daily') }})
select
    o.agency_slug,
    o.shop_slug,
    o.period,
    o.orders,
    o.revenue,
    o.avg_order_value,
    o.total_discounts,
    o.pct_discounted_orders,
    o.discount_depth,
    v.revenue_volatility
from o
left join v using (agency_slug, shop_slug, period)
