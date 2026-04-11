select
    dim_date.date_key,
    dim_etf.etf_key,
    metrics.close_price,
    metrics.return_1d,
    metrics.return_1w,
    metrics.return_1m,
    metrics.return_3m,
    metrics.return_6m,
    metrics.return_1y,
    metrics.volatility_30d,
    metrics.drawdown_52w,
    metrics.sharpe_proxy
from {{ ref('int_etf_daily_metrics') }} as metrics
inner join {{ ref('dim_date') }} as dim_date
    on metrics.trading_date = dim_date.full_date
inner join {{ ref('dim_etf') }} as dim_etf
    on metrics.ticker = dim_etf.ticker
