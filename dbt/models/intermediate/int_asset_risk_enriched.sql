select
    returns.asset_key,
    returns.ticker,
    returns.date_key,
    returns.full_date,
    returns.close_price,
    returns.adj_close_price,
    returns.price_for_returns,
    returns.daily_return,
    returns.return_1d,
    returns.return_1w,
    returns.return_1m,
    returns.return_3m,
    returns.return_6m,
    returns.return_1y,
    volatility.volatility_30d,
    volatility.volatility_90d,
    volatility.sharpe_proxy_1y,
    drawdown.drawdown_52w,
    drawdown.drawdown_since_inception
from {{ ref('int_asset_returns') }} as returns
left join {{ ref('int_asset_volatility') }} as volatility
    on returns.asset_key = volatility.asset_key
   and returns.full_date = volatility.full_date
left join {{ ref('int_asset_drawdown') }} as drawdown
    on returns.asset_key = drawdown.asset_key
   and returns.full_date = drawdown.full_date
