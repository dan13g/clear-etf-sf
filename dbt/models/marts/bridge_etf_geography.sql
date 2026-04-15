select
    etf.etf_key,
    geography.geography_key,
    stg_geography.exposure_weight
from {{ ref('stg_geography') }} as stg_geography
inner join {{ ref('dim_etf') }} as etf
    on stg_geography.etf_code = etf.etf_code
inner join {{ ref('dim_geography') }} as geography
    on stg_geography.geography_name = geography.geography_name
