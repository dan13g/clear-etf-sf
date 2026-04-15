select
    date_key,
    asset_key,
    full_date,
    open_price,
    high_price,
    low_price,
    close_price,
    adj_close_price,
    volume
from {{ ref('stg_asset_prices') }}
