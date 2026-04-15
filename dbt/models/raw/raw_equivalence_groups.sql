select
    cast(equivalence_group_code as varchar) as equivalence_group_code,
    cast(equivalence_group_name as varchar) as equivalence_group_name,
    cast(group_type as varchar) as group_type,
    cast(canonical_exposure as varchar) as canonical_exposure,
    cast(description as varchar) as description
from {{ source('motherduck_raw', 'equivalence_groups') }}
