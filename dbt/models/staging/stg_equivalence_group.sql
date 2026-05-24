select
    lower(nullif(trim(cast(equivalence_group_code as varchar)), '')) as equivalence_group_code,
    nullif(trim(cast(equivalence_group_name as varchar)), '') as equivalence_group_name,
    lower(nullif(trim(cast(group_type as varchar)), '')) as group_type,
    nullif(trim(cast(canonical_exposure as varchar)), '') as canonical_exposure,
    nullif(trim(cast(description as varchar)), '') as description
from {{ source('snowflake_raw', 'equivalence_groups') }}
where nullif(trim(cast(equivalence_group_code as varchar)), '') is not null
