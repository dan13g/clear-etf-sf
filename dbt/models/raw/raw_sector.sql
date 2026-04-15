select
    cast(etf as varchar) as etf_code,
    cast(sector as varchar) as sector_name,
    cast(exposure_weight as double) as exposure_weight
from {{ source('motherduck_raw', 'etf_sector') }}
