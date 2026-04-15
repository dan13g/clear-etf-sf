select
    profile.asset_key,
    asset.ticker,
    asset.asset_name,
    profile.equivalence_group_code,
    eq.equivalence_group_name,
    profile.ter,
    avg(profile.ter) over (
        partition by profile.equivalence_group_code
    ) as group_avg_ter,
    min(profile.ter) over (
        partition by profile.equivalence_group_code
    ) as group_min_ter,
    max(profile.ter) over (
        partition by profile.equivalence_group_code
    ) as group_max_ter,
    percent_rank() over (
        partition by profile.equivalence_group_code
        order by profile.ter
    ) as ter_percentile
from {{ ref('dim_etf_profile') }} as profile
inner join {{ ref('dim_asset') }} as asset
    on profile.asset_key = asset.asset_key
left join {{ ref('dim_equivalence_group') }} as eq
    on md5(profile.equivalence_group_code) = eq.equivalence_group_key
