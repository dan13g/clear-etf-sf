select
    upper(nullif(trim(etf_code), '')) as etf_code,
    nullif(trim(geography_name), '') as geography_name,
    exposure_weight
from {{ ref('raw_geography') }}
where nullif(trim(etf_code), '') is not null
  and nullif(trim(geography_name), '') is not null
