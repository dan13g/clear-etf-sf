select
    cast(source_group_code as varchar) as source_group_code,
    cast(target_group_code as varchar) as target_group_code,
    cast(relationship_type as varchar) as relationship_type,
    cast(priority_rank as integer) as priority_rank,
    cast(notes as varchar) as notes
from {{ source('motherduck_raw', 'equivalence_group_relationships') }}
