select
    asset.asset_key,
    upper(nullif(trim(cast(raw.etf as varchar)), '')) as etf_code,
    asset.ticker,
    asset.asset_name,
    nullif(trim(cast(raw.isin as varchar)), '') as isin,
    nullif(trim(cast(raw.fund_name as varchar)), '') as fund_name,
    case lower(trim(cast(raw.provider as varchar)))
        when 'vanguard' then 'Vanguard'
        when 'ishares' then 'iShares'
        when 'invesco' then 'Invesco'
        when 'spdr' then 'SPDR'
        when 'amundi' then 'Amundi'
        when 'l&g' then 'L&G'
        else nullif(trim(cast(raw.provider as varchar)), '')
    end as provider_name,
    nullif(trim(cast(raw."index" as varchar)), '') as index_code,
    replace(nullif(trim(cast(raw."index" as varchar)), ''), '_', ' ') as index_name,
    lower(nullif(trim(cast(raw.equivalence_group_code as varchar)), '')) as equivalence_group_code,
    lower(nullif(trim(cast(raw.relationship_to_group as varchar)), '')) as relationship_to_group,
    nullif(trim(cast(raw.asset_class as varchar)), '') as asset_class,
    nullif(trim(cast(raw.category as varchar)), '') as category,
    nullif(trim(cast(raw.distribution_type as varchar)), '') as distribution_type,
    nullif(trim(cast(raw.replication_method as varchar)), '') as replication_method,
    nullif(trim(cast(raw.currency as varchar)), '') as currency,
    nullif(trim(cast(raw.domicile as varchar)), '') as domicile,
    case lower(trim(cast(raw.hedged_flag as varchar)))
        when 'yes' then true
        when 'no' then false
        else null
    end as hedged_flag,
    case lower(trim(cast(raw.ucits_flag as varchar)))
        when 'yes' then true
        when 'no' then false
        else null
    end as ucits_flag,
    cast(raw.ter as double) as ter,
    cast(raw.inception_date as date) as inception_date,
    case lower(trim(cast(raw.is_active as varchar)))
        when 'yes' then true
        when 'no' then false
        else null
    end as is_active,
    nullif(trim(cast(raw.notes as varchar)), '') as notes
from {{ source('motherduck_raw', 'etf_metadata') }} as raw
inner join {{ ref('stg_asset_master') }} as asset
    on upper(cast(raw.ticker as varchar)) = asset.ticker
where nullif(trim(cast(raw.etf as varchar)), '') is not null
