{{ config(materialized='table') }}

select
  ol.agency_slug,
  ol.shop_slug,
  ol.period,
  ol.order_id,
  ol.order_name,
  ol.email,
  ol.financial_status,
  ol.paid_at,
  ol.fulfillment_status,
  ol.fulfilled_at,
  ol.currency,
  ol.subtotal_amount,
  ol.shipping_amount,
  ol.tax_amount,
  ol.total_amount,
  ol.discount_code,
  ol.discount_amount,
  ol.created_at,
  ol.line_item_qty,
  ol.line_name,
  ol.line_price,
  ol.line_total,
  ol.line_total_net,
  ol.line_compare_at_price,
  ol.line_sku,
  ol.line_fulfillment_status,
  ol.billing_name,
  ol.billing_country,
  ol.refunded_amount,
  ol.outstanding_balance,
  ol.line_discount,

  c.customer_id,
  c.first_name,
  c.last_name,
  c.total_orders as customer_total_orders,
  c.total_spent as customer_total_spent,

  p.handle as product_handle,
  p.title as product_title,
  p.vendor as product_vendor,
  p.product_category,
  p.product_type,
  p.variant_sku,
  p.variant_inventory_qty,
  p.variant_price,
  p.variant_compare_at_price,
  p.cost_per_item,
  p.status as product_status,

  d.discount_code,
  d.value as discount_value,
  d.value_type as discount_value_type,
  d.type as discount_type,
  d.times_used as discount_times_used,
  d.status as discount_status,
  d.starts_date as discount_starts_date,
  d.ends_date as discount_ends_date
from {{ ref('stg_orders_lines') }} ol
left join {{ ref('stg_customers') }} c
  on ol.shop_slug = c.shop_slug
  and ol.period = c.period
  and ol.email = c.email
left join {{ ref('stg_products') }} p
  on ol.shop_slug = p.shop_slug
  and ol.period = p.period
  and ol.line_sku = p.variant_sku
left join {{ ref('stg_discounts') }} d
  on ol.shop_slug = d.shop_slug
  and ol.period = d.period
  and trim(split_part(ol.discount_code, ',', 1)) = d.discount_code
