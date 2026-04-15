select
    etf.asset_key as etf_key,
    geography.geography_key,
    stg_geography.exposure_weight
from {{ ref('stg_etf_geography') }} as stg_geography
inner join {{ ref('dim_etf_profile') }} as etf
    on stg_geography.asset_key = etf.asset_key
inner join {{ ref('dim_geography') }} as geography
    on stg_geography.geography_name = geography.geography_name
