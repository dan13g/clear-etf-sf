select
    dim_date.full_date,
    dim_etf.ticker,
    dim_etf.fund_name,
    dim_provider.provider_name,
    dim_index.index_name,
    dim_equivalence_group.equivalence_group_name,
    fact.close_price,
    fact.return_1d,
    fact.return_1w,
    fact.return_1m,
    fact.return_3m,
    fact.return_6m,
    fact.return_1y,
    fact.volatility_30d,
    fact.drawdown_52w,
    fact.sharpe_proxy
from {{ ref('fact_etf_daily') }} as fact
inner join {{ ref('dim_date') }} as dim_date
    on fact.date_key = dim_date.date_key
inner join {{ ref('dim_etf') }} as dim_etf
    on fact.etf_key = dim_etf.etf_key
inner join {{ ref('dim_provider') }} as dim_provider
    on dim_etf.provider_key = dim_provider.provider_key
inner join {{ ref('dim_index') }} as dim_index
    on dim_etf.index_key = dim_index.index_key
inner join {{ ref('dim_equivalence_group') }} as dim_equivalence_group
    on dim_etf.equivalence_group_key = dim_equivalence_group.equivalence_group_key
