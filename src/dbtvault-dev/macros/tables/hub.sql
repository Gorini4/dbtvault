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
{%- macro hub(src_pk, src_nk, src_ldts, src_source,
              source) -%}

{%- set source_data = dbtvault.is_multi_source(source, src_pk, src_nk, src_ldts, src_source) -%}
{%- set source_col = source_data[0] -%}
{%- set is_union = source_data[1] -%}

-- Generated by dbtvault.
SELECT DISTINCT {{ dbtvault.prefix([src_pk, src_nk, src_ldts, src_source], 'stg') }}
FROM (
    {{ source_col }}
) AS stg
{# If incremental union or single #}
{%- if is_incremental() -%}
LEFT JOIN {{ this }} AS tgt
ON {{ dbtvault.prefix([src_pk], 'stg') }} = {{ dbtvault.prefix([src_pk], 'tgt') }}
WHERE {{ dbtvault.prefix([src_pk], 'tgt') }} IS NULL
{# If an incremental and union load -#}
{% if is_union -%}
AND stg.FIRST_SOURCE IS NULL
{%- endif -%}
{%- endif -%}
{# If a union base-load #}
{%- if is_union and not is_incremental() -%}
WHERE stg.FIRST_SOURCE IS NULL
{%- endif -%}
{%- endmacro -%}