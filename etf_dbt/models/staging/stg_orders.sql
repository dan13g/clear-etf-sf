{{ config(materialized='table') }}

-- This collapses repeated line-item rows into 1 row per order_id (order-level).

with base as (
  select
    agency_slug,
    shop_slug,
    period_ym                   as period,
    "Id" ::bigint               as order_id,
    "Name"                      as order_name,
    "Email"                     as email,
    "Financial Status"          as financial_status,
    "Paid at"                   as paid_at,
    "Fulfillment Status"        as fulfillment_status,
    "Fulfilled at"              as fulfilled_at,
    "Currency"                  as currency,
    "Subtotal"  :: decimal(19, 2)                 as subtotal_amount,
    "Shipping"  :: decimal(19, 2)                 as shipping_amount,
    "Taxes"   :: decimal(19, 2)                   as tax_amount,
    "Total"  :: decimal(19, 2)                    as total_amount,
    "Discount Code"                       as discount_code,
    "Discount Amount" :: decimal(19, 2)   as discount_amount,
    "Created at"                          as created_at,
    "Lineitem quantity" ::integer         as line_item_qty,
    "Lineitem name"                       as line_name,
    "Lineitem price" :: decimal(19, 2)                     as line_price,
    "Lineitem compare at price" :: decimal(19, 2)          as line_compare_at_price,
    "Lineitem sku"                        as line_sku,
    "Lineitem fulfillment status"         as line_fulfillment_status,
    "Billing Name"                        as billing_name,
    "Billing Country"                     as billing_country,
    "Refunded Amount"  :: decimal(19, 2)  as refunded_amount,
    "Outstanding Balance"                 as outstanding_balance,
    "Lineitem discount":: decimal(19, 2)  as line_discount,
    filename,
    ingested_at_utc
  from {{ ref('raw_orders') }}
),

latest_ingest as (
  select
    *,
    max(ingested_at_utc) over (
      partition by agency_slug, shop_slug, period, order_id, order_name
    ) as max_ingested_at_utc
  from base
  where order_id is not null or order_name is not null
),

base_latest as (
  select *
  from latest_ingest
  where ingested_at_utc = max_ingested_at_utc
),

dedupe as (
  select
    agency_slug,
    shop_slug,
    period,
    order_id,
    max(order_name) as order_name,
    max(email) as email,
    max(financial_status) as financial_status,
    max(paid_at) as paid_at,
    max(fulfillment_status) as fulfillment_status,
    max(fulfilled_at) as fulfilled_at,
    max(currency) as currency,
    max(subtotal_amount) as subtotal_amount,
    max(shipping_amount) as shipping_amount,
    max(tax_amount) as tax_amount,
    max(total_amount) as total_amount,
    max(discount_code) as discount_code,
    max(discount_amount) as discount_amount,
    max(created_at) as created_at,
    max(line_item_qty) as line_item_qty,
    max(line_name) as line_name,
    max(line_price) as line_price,
    max(line_compare_at_price) as line_compare_at_price,
    max(line_sku) as line_sku,
    max(line_fulfillment_status) as line_fulfillment_status,
    max(billing_name) as billing_name,
    max(billing_country) as billing_country,
    max(refunded_amount) as refunded_amount,
    max(outstanding_balance) as outstanding_balance,
    max(line_discount) as line_discount,
    max(filename) as filename
  from base_latest
  where order_id is not null
  group by 1,2,3,4
)

select * from dedupe
