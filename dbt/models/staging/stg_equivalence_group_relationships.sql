select
    lower(nullif(trim(cast(source_group_code as varchar)), '')) as source_group_code,
    lower(nullif(trim(cast(target_group_code as varchar)), '')) as target_group_code,
    lower(nullif(trim(cast(relationship_type as varchar)), '')) as relationship_type,
    cast(priority_rank as integer) as priority_rank,
    nullif(trim(cast(notes as varchar)), '') as notes
from {{ source('motherduck_raw', 'equivalence_group_relationships') }}
where nullif(trim(cast(source_group_code as varchar)), '') is not null
  and nullif(trim(cast(target_group_code as varchar)), '') is not null
