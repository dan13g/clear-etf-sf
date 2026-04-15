select
    etf_code,
    sector_name,
    exposure_weight
from {{ ref('stg_etf_sector') }}
