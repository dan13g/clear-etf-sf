with sector_pairs as (
    select
        left_sector.asset_key,
        right_sector.asset_key as compare_asset_key,
        sum(least(left_sector.exposure_weight, right_sector.exposure_weight)) as sector_overlap_score
    from {{ ref('stg_etf_sector') }} as left_sector
    inner join {{ ref('stg_etf_sector') }} as right_sector
        on left_sector.sector_name = right_sector.sector_name
       and left_sector.asset_key < right_sector.asset_key
    group by 1, 2
),
geography_pairs as (
    select
        left_geo.asset_key,
        right_geo.asset_key as compare_asset_key,
        sum(least(left_geo.exposure_weight, right_geo.exposure_weight)) as geography_overlap_score
    from {{ ref('stg_etf_geography') }} as left_geo
    inner join {{ ref('stg_etf_geography') }} as right_geo
        on left_geo.geography_name = right_geo.geography_name
       and left_geo.asset_key < right_geo.asset_key
    group by 1, 2
)
select
    coalesce(sector_pairs.asset_key, geography_pairs.asset_key) as asset_key,
    asset.ticker,
    asset.asset_name,
    coalesce(sector_pairs.compare_asset_key, geography_pairs.compare_asset_key) as compare_asset_key,
    compare_asset.ticker as compare_ticker,
    compare_asset.asset_name as compare_asset_name,
    sector_pairs.sector_overlap_score,
    geography_pairs.geography_overlap_score,
    (
        coalesce(sector_pairs.sector_overlap_score, 0)
        + coalesce(geography_pairs.geography_overlap_score, 0)
    ) / nullif(
        case
            when sector_pairs.sector_overlap_score is not null and geography_pairs.geography_overlap_score is not null then 2
            else 1
        end,
        0
    ) as blended_overlap_score
from sector_pairs
full outer join geography_pairs
    on sector_pairs.asset_key = geography_pairs.asset_key
   and sector_pairs.compare_asset_key = geography_pairs.compare_asset_key
inner join {{ ref('dim_asset') }} as asset
    on coalesce(sector_pairs.asset_key, geography_pairs.asset_key) = asset.asset_key
inner join {{ ref('dim_asset') }} as compare_asset
    on coalesce(sector_pairs.compare_asset_key, geography_pairs.compare_asset_key) = compare_asset.asset_key
