select
    upper(nullif(trim(etf_code), '')) as etf_code,
    nullif(trim(sector_name), '') as sector_name,
    exposure_weight
from {{ ref('raw_sector') }}
where nullif(trim(etf_code), '') is not null
  and nullif(trim(sector_name), '') is not null
