select
    etf.asset_key as etf_key,
    sector.sector_key,
    stg_sector.exposure_weight
from {{ ref('stg_etf_sector') }} as stg_sector
inner join {{ ref('dim_etf_profile') }} as etf
    on stg_sector.asset_key = etf.asset_key
inner join {{ ref('dim_sector') }} as sector
    on stg_sector.sector_name = sector.sector_name
