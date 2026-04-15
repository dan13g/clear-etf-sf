select
    cast(ticker as varchar) as ticker,
    cast(date as date) as trading_date,
    cast(open as double) as open_price,
    cast(high as double) as high_price,
    cast(low as double) as low_price,
    cast(close as double) as close_price,
    cast(adj_close as double) as adj_close_price,
    cast(volume as double) as volume
from {{ source('motherduck_raw', 'asset_prices_yfinance') }}
