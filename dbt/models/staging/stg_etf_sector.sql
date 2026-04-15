select
    etf.asset_key,
    etf.etf_code,
    etf.ticker,
    nullif(trim(cast(raw.sector as varchar)), '') as sector_name,
    cast(raw.exposure_weight as double) as exposure_weight
from {{ source('motherduck_raw', 'etf_sector') }} as raw
inner join {{ ref('stg_etf_metadata') }} as etf
    on upper(cast(raw.etf as varchar)) = etf.etf_code
where nullif(trim(cast(raw.sector as varchar)), '') is not null
