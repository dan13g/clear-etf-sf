select
    mart.full_date,
    mart.ticker,
    profile.fund_name,
    provider.provider_name,
    idx.index_name,
    eq.equivalence_group_name,
    mart.close_price,
    mart.return_1d,
    mart.return_1w,
    mart.return_1m,
    mart.return_3m,
    mart.return_6m,
    mart.return_1y,
    risk.volatility_30d,
    risk.drawdown_52w,
    risk.sharpe_proxy_1y as sharpe_proxy
from {{ ref('mart_asset_returns') }} as mart
inner join {{ ref('dim_etf') }} as dim_etf
    on mart.asset_key = dim_etf.etf_key
left join {{ ref('dim_etf_profile') }} as profile
    on mart.asset_key = profile.asset_key
left join {{ ref('dim_provider') }} as provider
    on dim_etf.provider_key = provider.provider_key
left join {{ ref('dim_index') }} as idx
    on dim_etf.index_key = idx.index_key
left join {{ ref('dim_equivalence_group') }} as eq
    on dim_etf.equivalence_group_key = eq.equivalence_group_key
left join {{ ref('mart_asset_risk') }} as risk
    on mart.asset_key = risk.asset_key
   and mart.full_date = risk.full_date
