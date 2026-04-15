with sectors as (
    select distinct
        sector_name
    from {{ ref('stg_etf_sector') }}
)
select
    md5(lower(sector_name)) as sector_key,
    sector_name
from sectors
