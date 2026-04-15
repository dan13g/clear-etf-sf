select
    etf_code,
    geography_name,
    exposure_weight
from {{ ref('stg_etf_geography') }}
