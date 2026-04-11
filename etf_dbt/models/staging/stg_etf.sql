select
    upper(nullif(trim(etf_code), '')) as etf_code,
    upper(nullif(trim(ticker), '')) as ticker,
    nullif(trim(isin), '') as isin,
    nullif(trim(fund_name), '') as fund_name,
    case lower(trim(provider_name))
        when 'vanguard' then 'Vanguard'
        when 'ishares' then 'iShares'
        when 'invesco' then 'Invesco'
        when 'spdr' then 'SPDR'
        when 'amundi' then 'Amundi'
        when 'l&g' then 'L&G'
        else nullif(trim(provider_name), '')
    end as provider_name,
    nullif(trim(index_code), '') as index_code,
    lower(nullif(trim(equivalence_group_code), '')) as equivalence_group_code,
    lower(nullif(trim(relationship_to_group), '')) as relationship_to_group,
    nullif(trim(asset_class), '') as asset_class,
    nullif(trim(category), '') as category,
    nullif(trim(distribution_type), '') as distribution_type,
    nullif(trim(replication_method), '') as replication_method,
    nullif(trim(currency), '') as currency,
    nullif(trim(domicile), '') as domicile,
    case lower(trim(hedged_flag))
        when 'yes' then true
        when 'no' then false
        else null
    end as hedged_flag,
    case lower(trim(ucits_flag))
        when 'yes' then true
        when 'no' then false
        else null
    end as ucits_flag,
    ter,
    inception_date,
    case lower(trim(is_active))
        when 'yes' then true
        when 'no' then false
        else null
    end as is_active,
    nullif(trim(notes), '') as notes
from {{ ref('raw_etf') }}
where nullif(trim(etf_code), '') is not null
