with ranked_moves as (
    select
        returns.full_date,
        returns.date_key,
        asset.asset_key,
        asset.ticker,
        asset.asset_name,
        asset.asset_type,
        asset.region,
        returns.return_1d,
        abs(returns.return_1d) as abs_return_1d,
        row_number() over (
            partition by returns.full_date
            order by abs(returns.return_1d) desc, asset.ticker
        ) as move_rank
    from {{ ref('int_asset_returns') }} as returns
    inner join {{ ref('dim_asset') }} as asset
        on returns.asset_key = asset.asset_key
    where returns.return_1d is not null
)
select
    *,
    case
        when return_1d > 0 then 'Up'
        when return_1d < 0 then 'Down'
        else 'Flat'
    end as move_direction
from ranked_moves
