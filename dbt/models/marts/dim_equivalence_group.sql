select
    md5(equivalence_group_code) as equivalence_group_key,
    equivalence_group_code,
    equivalence_group_name,
    group_type,
    description,
    canonical_exposure
from {{ ref('stg_equivalence_group') }}
