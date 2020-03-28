{#- Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
-#}
{%- macro eff_sat(src_pk, src_dfk, src_sfk, src_ldts, src_eff_from, src_start_date, src_end_date, src_source, link, source)-%}

{%- set source_cols = dbtvault.get_src_col_list([src_pk, src_ldts, src_eff_from, src_start_date, src_end_date, src_source])-%}
{%- set max_date = "'" ~ '9999-12-31' ~ "'" -%}

WITH
{#- Reduce data set to size of stage table. #}
c AS (SELECT DISTINCT
            {{ dbtvault.prefix(source_cols, 'a') }}
            FROM {{ this }} AS a
            INNER JOIN {{ ref(source) }} AS b ON {{ dbtvault.prefix([src_pk], 'a') }}={{ dbtvault.prefix([src_pk], 'b') }}
            )
{# Find latest satellite for each pk in set c. -#}
, d as (SELECT
          {{ dbtvault.prefix(source_cols, 'c') }},
          CASE WHEN RANK()
          OVER (PARTITION BY {{ dbtvault.prefix([src_pk], 'c') }}
          ORDER BY {{ dbtvault.prefix([src_end_date], 'c') }} ASC) = 1
          THEN 'Y' ELSE 'N' END AS CURR_FLG
        FROM c)
, p AS (
    SELECT q.* FROM {{ ref(link) }} AS q
    INNER JOIN {{ ref(source) }} AS r ON {{ dbtvault.prefix([src_dfk], 'q') }}={{ dbtvault.prefix([src_dfk], 'r') }}
)
, x AS (
    SELECT p.*, {{ dbtvault.prefix([src_dfk], 's') }} AS STG_CUSTOMER_FK
    FROM p
    LEFT JOIN {{ ref(source) }} AS s ON {{ dbtvault.prefix([src_dfk], 'p') }}={{ dbtvault.prefix([src_dfk], 's') }}
    AND {{ dbtvault.prefix([src_sfk], 'p') }}={{ dbtvault.prefix([src_sfk], 's') }}
    WHERE ({{ dbtvault.prefix([src_dfk], 's') }} IS NULL AND {{ dbtvault.prefix([src_sfk], 's') }} IS NULL)
)
, y AS (
  SELECT
    {{ dbtvault.prefix([src_pk, src_ldts, src_source, src_eff_from, src_start_date, src_end_date], 't') }},
    {{ dbtvault.prefix(['STG_CUSTOMER_FK'], 'x') }},
    {{ dbtvault.prefix([src_dfk], 'x')}},
    CASE WHEN RANK()
    OVER (PARTITION BY {{ dbtvault.prefix([src_pk], 't') }}
    ORDER BY {{ dbtvault.prefix([src_end_date], 't') }} ASC) = 1
    THEN 'Y' ELSE 'N' END AS CURR_FLG
  FROM x
  INNER JOIN {{ this }} AS t ON {{ dbtvault.prefix([src_pk], 'x') }}={{ dbtvault.prefix([src_pk], 't') }}
  )

SELECT DISTINCT
  {{ dbtvault.prefix([src_pk, src_ldts, src_source, src_eff_from], 'e') }},
  {{ dbtvault.prefix([src_eff_from], 'e') }} AS {{ src_start_date }},
  {{ dbtvault.prefix([src_end_date], 'e') }}
FROM {{ ref(source) }} AS e
{% if is_incremental() -%}
LEFT JOIN (
    SELECT {{ dbtvault.prefix(source_cols, 'd')}}
    FROM d
    WHERE d.CURR_FLG = 'Y' AND {{ dbtvault.prefix([src_end_date], 'd') }}=TO_DATE({{ max_date }})
    ) AS eff
ON {{ dbtvault.prefix([src_pk], 'eff') }}={{ dbtvault.prefix([src_pk], 'e') }}
WHERE {{ dbtvault.prefix([src_pk], 'eff') }} IS NULL
UNION
SELECT
  {{ dbtvault.prefix([src_pk], 'y') }},
  {{ dbtvault.prefix([src_ldts], 'z') }},
  {{ dbtvault.prefix([src_source, src_eff_from, src_start_date], 'y') }},
  CASE WHEN y.STG_CUSTOMER_FK IS NULL
  THEN {{ dbtvault.prefix([src_eff_from], 'z') }} ELSE {{ max_date }} END AS {{ src_end_date }}
FROM y
LEFT JOIN {{ ref(source) }} AS z ON {{ dbtvault.prefix([src_dfk], 'y') }}={{ dbtvault.prefix([src_dfk], 'z') }}
WHERE y.CURR_FLG='Y' AND {{ dbtvault.prefix([src_end_date], 'y') }}={{ max_date }}
{%- endif -%}

{% endmacro %}