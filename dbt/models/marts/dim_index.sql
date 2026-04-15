with indexes as (
    select
        index_code,
        min(asset_class) as asset_class
    from {{ ref('stg_etf') }}
    where index_code is not null
    group by 1
)
select
    md5(index_code) as index_key,
    case
        when index_code = 'FTSE_ALL_WORLD' then 'FTSE All-World'
        when index_code = 'S&P_500' then 'S&P 500'
        when index_code = 'MSCI_ACWI' then 'MSCI ACWI'
        when index_code = 'FTSE_EMERGING' then 'FTSE Emerging'
        when index_code = 'BLOOMBERG_GLOBAL_AGGREGATE' then 'Bloomberg Global Aggregate'
        else replace(index_code, '_', ' ')
    end as index_name,
    case
        when index_code like 'FTSE_%' then 'FTSE'
        when index_code like 'MSCI_%' then 'MSCI'
        when index_code like 'S&P_%' then 'S&P'
        when index_code like 'BLOOMBERG_%' then 'Bloomberg'
        else split_part(index_code, '_', 1)
    end as index_family,
    case
        when index_code = 'S&P_500' then 'US'
        when index_code like '%EMERGING%' then 'Emerging Markets'
        when index_code like '%ALL_WORLD%' or index_code like '%ACWI%' or index_code like '%GLOBAL%' then 'Global'
        else 'Other'
    end as broad_region_type,
    case
        when index_code in ('FTSE_ALL_WORLD', 'MSCI_ACWI', 'S&P_500', 'BLOOMBERG_GLOBAL_AGGREGATE') then true
        when index_code like '%EMERGING%' then false
        else null
    end as developed_flag,
    case
        when index_code in ('FTSE_ALL_WORLD', 'MSCI_ACWI', 'FTSE_EMERGING') then true
        when index_code in ('S&P_500', 'BLOOMBERG_GLOBAL_AGGREGATE') then false
        when index_code like '%EMERGING%' then true
        else null
    end as emerging_flag,
    asset_class,
    index_code
from indexes
