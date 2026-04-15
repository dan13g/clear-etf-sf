with latest_risk as (
    select *
    from (
        select
            asset_key,
            volatility_30d,
            drawdown_52w,
            row_number() over (partition by asset_key order by full_date desc) as row_num
        from {{ ref('int_asset_risk_enriched') }}
    )
    where row_num = 1
),
latest_trend as (
    select *
    from (
        select
            asset_key,
            trend_label,
            row_number() over (partition by asset_key order by full_date desc) as row_num
        from {{ ref('int_asset_trend_inputs') }}
    )
    where row_num = 1
)
select
    asset.asset_key,
    case
        when asset.asset_type in ('Index', 'FX', 'Commodity', 'Bond Proxy') then 'Macro Indicator'
        when asset.asset_type = 'ETF' and lower(coalesce(asset.asset_subtype, '')) like '%bond%' then 'Defensive'
        when asset.asset_type = 'ETF' then 'Core'
        when asset.asset_type = 'Stock' then 'Growth'
        else 'Satellite'
    end as role,
    case
        when risk.volatility_30d is null then null
        when risk.volatility_30d < 0.10 then 'Low'
        when risk.volatility_30d < 0.20 then 'Medium'
        else 'High'
    end as risk_band,
    case
        when risk.volatility_30d is null then null
        when risk.volatility_30d < 0.10 then 'Low Vol'
        when risk.volatility_30d < 0.20 then 'Mid Vol'
        else 'High Vol'
    end as volatility_bucket,
    case
        when risk.drawdown_52w is null then null
        when risk.drawdown_52w > -0.10 then 'Shallow'
        when risk.drawdown_52w > -0.20 then 'Moderate'
        else 'Deep'
    end as drawdown_bucket,
    trend.trend_label as trend_category,
    case
        when asset.asset_type = 'ETF' and lower(coalesce(asset.asset_subtype, '')) like '%global%' then 'Core'
        when asset.asset_type = 'ETF' then 'Satellite'
        else null
    end as core_satellite_flag,
    cast(null as varchar) as notes
from {{ ref('dim_asset') }} as asset
left join latest_risk as risk
    on asset.asset_key = risk.asset_key
left join latest_trend as trend
    on asset.asset_key = trend.asset_key
