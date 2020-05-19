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
{%- macro stage(include_source_columns=none, source_model=none, hashed_columns=none, derived_columns=none) -%}

    {% if include_source_columns is none %}
        {%- set include_source_columns = true -%}
    {% endif %}

    {{- adapter_macro('dbtvault.stage', include_source_columns=include_source_columns, source_model=source_model, hashed_columns=hashed_columns, derived_columns=derived_columns) -}}
{%- endmacro -%}

{%- macro default__stage(include_source_columns, source_model, hashed_columns, derived_columns) -%}
-- Generated by dbtvault.

{% if (source_model is none) and execute %}

    {%- set error_message -%}
    "Staging error: Missing source_model configuration. A source model name must be provided.
    e.g. 
    [REF STYLE]
    source_model: model_name
    OR
    [SOURCES STYLE]
    source_model:
    source_name: source_table_name"
    {%- endset -%}
    
    {{- exceptions.raise_compiler_error(error_message) -}}
{%- endif -%}

SELECT

{# Create relation object from provided source_model -#}
{% if source_model is mapping and source_model is not none -%}

    {%- set source_name = source_model | first -%}
    {%- set source_table_name = source_model[source_name] -%}

    {%- set source_relation = source(source_name, source_table_name) -%}

{%- elif source_model is not mapping and source_model is not none -%}

    {%- set source_relation = ref(source_model) -%}
{%- endif -%}

{#- Hash columns, if provided -#}
{% if hashed_columns is defined and hashed_columns is not none -%}
    
    {{ dbtvault.hash_columns(columns=hashed_columns) -}}
    {{ "," if derived_columns is defined and source_relation is defined and include_source_columns }}

{% endif -%}

{#- Derive additional columns, if provided -#}
{%- if derived_columns is defined and derived_columns is not none -%}

    {%- if include_source_columns -%}
    {{ dbtvault.derive_columns(source_relation=source_relation, columns=derived_columns) }}
    {%- else -%}
    {{ dbtvault.derive_columns(columns=derived_columns) }}
    {%- endif -%}
{#- If source relation is defined but derived_columns is not, add columns from source model. -#}
{%- elif source_relation is defined and include_source_columns is true -%}
 
    {{ dbtvault.derive_columns(source_relation=source_relation) }}
{%- endif %}

FROM {{ source_relation }}

{%- endmacro -%}