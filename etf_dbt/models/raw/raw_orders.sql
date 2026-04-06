{{ config(materialized='table') }}

with src as (
  select
    *,
    filename as _filename
  from read_csv_auto(
    's3://{{ var('s3_bucket', 'intelken-shopify') }}/{{ var('s3_prefix', 'raw') }}/*/*/*/*_products_*.csv',
    union_by_name=true,
    filename=true
  )
)
select
  regexp_extract(_filename, '/raw/([^/]+)/', 1) as agency_slug,
  regexp_extract(_filename, '/raw/[^/]+/([^/]+)/', 1) as shop_slug,
  regexp_extract(_filename, '/raw/[^/]+/[^/]+/([0-9]{4}-[0-9]{2})/', 1) as period_ym,
  *
from src
