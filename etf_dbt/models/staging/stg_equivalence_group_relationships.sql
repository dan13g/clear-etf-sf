select
    lower(nullif(trim(source_group_code), '')) as source_group_code,
    lower(nullif(trim(target_group_code), '')) as target_group_code,
    lower(nullif(trim(relationship_type), '')) as relationship_type,
    priority_rank,
    nullif(trim(notes), '') as notes
from {{ ref('raw_equivalence_group_relationships') }}
where nullif(trim(source_group_code), '') is not null
  and nullif(trim(target_group_code), '') is not null
