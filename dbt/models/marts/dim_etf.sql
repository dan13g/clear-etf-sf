select
    profile.asset_key as etf_key,
    profile.etf_code,
    asset.ticker,
    profile.isin,
    coalesce(profile.fund_name, asset.asset_name) as fund_name,
    md5(lower(profile.provider_name)) as provider_key,
    md5(profile.index_code) as index_key,
    md5(profile.equivalence_group_code) as equivalence_group_key,
    profile.asset_class,
    profile.category,
    profile.distribution_type,
    profile.replication_method,
    profile.currency,
    profile.domicile,
    profile.hedged_flag,
    profile.ucits_flag,
    profile.ter,
    profile.inception_date,
    profile.is_active
from {{ ref('dim_etf_profile') }} as profile
inner join {{ ref('dim_asset') }} as asset
    on profile.asset_key = asset.asset_key
