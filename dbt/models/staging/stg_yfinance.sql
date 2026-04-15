select
    upper(nullif(trim(ticker), '')) as ticker,
    trading_date,
    open_price,
    high_price,
    low_price,
    close_price,
    adj_close_price,
    volume
from {{ ref('raw_yfinance') }}
where nullif(trim(ticker), '') is not null
  and trading_date is not null
