select
    cast(etf as varchar) as etf_code,
    cast(geography as varchar) as geography_name,
    cast(exposure_weight as double) as exposure_weight
from {{ source('motherduck_raw', 'etf_geography') }}
