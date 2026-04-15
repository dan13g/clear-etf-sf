select
    lower(nullif(trim(equivalence_group_code), '')) as equivalence_group_code,
    nullif(trim(equivalence_group_name), '') as equivalence_group_name,
    lower(nullif(trim(group_type), '')) as group_type,
    nullif(trim(canonical_exposure), '') as canonical_exposure,
    nullif(trim(description), '') as description
from {{ ref('raw_equivalence_groups') }}
where nullif(trim(equivalence_group_code), '') is not null
