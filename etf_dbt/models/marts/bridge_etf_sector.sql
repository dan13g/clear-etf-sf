select
    etf.etf_key,
    sector.sector_key,
    stg_sector.exposure_weight
from {{ ref('stg_sector') }} as stg_sector
inner join {{ ref('dim_etf') }} as etf
    on stg_sector.etf_code = etf.etf_code
inner join {{ ref('dim_sector') }} as sector
    on stg_sector.sector_name = sector.sector_name
