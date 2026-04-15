select
    etf.asset_key,
    etf.etf_code,
    etf.ticker,
    nullif(trim(cast(raw.geography as varchar)), '') as geography_name,
    cast(raw.exposure_weight as double) as exposure_weight
from {{ source('motherduck_raw', 'etf_geography') }} as raw
inner join {{ ref('stg_etf_metadata') }} as etf
    on upper(cast(raw.etf as varchar)) = etf.etf_code
where nullif(trim(cast(raw.geography as varchar)), '') is not null
