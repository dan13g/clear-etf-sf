select
    left_profile.asset_key,
    left_asset.ticker,
    left_asset.asset_name,
    right_profile.asset_key as compare_asset_key,
    right_asset.ticker as compare_ticker,
    right_asset.asset_name as compare_asset_name,
    left_profile.equivalence_group_code,
    eq.equivalence_group_name,
    left_profile.ter,
    right_profile.ter as compare_ter,
    left_profile.ter - right_profile.ter as ter_spread,
    case
        when left_profile.ter < right_profile.ter then left_asset.ticker
        when left_profile.ter > right_profile.ter then right_asset.ticker
        else null
    end as lower_fee_ticker
from {{ ref('dim_etf_profile') }} as left_profile
inner join {{ ref('dim_etf_profile') }} as right_profile
    on left_profile.equivalence_group_code = right_profile.equivalence_group_code
   and left_profile.asset_key < right_profile.asset_key
inner join {{ ref('dim_asset') }} as left_asset
    on left_profile.asset_key = left_asset.asset_key
inner join {{ ref('dim_asset') }} as right_asset
    on right_profile.asset_key = right_asset.asset_key
left join {{ ref('dim_equivalence_group') }} as eq
    on md5(left_profile.equivalence_group_code) = eq.equivalence_group_key
