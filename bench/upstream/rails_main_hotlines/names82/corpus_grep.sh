#!/usr/bin/env bash
# corpus_grep.sh DIR: sparse shallow clones (app lib config engines ee) of every repo in corpus.txt into DIR, then
# corpus-hits.txt: each repo's default-branch SHA and every line that defines or uses one of the collision names.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd) dir=$1
mkdir -p "$dir"
grep -v '^#' "$here/corpus.txt" | while read -r repo; do
  [ -z "$repo" ] && continue
  d="$dir/${repo//\//__}"
  [ -d "$d" ] || { git clone -q --depth 1 --filter=blob:none --sparse "https://github.com/$repo.git" "$d" && git -C "$d" sparse-checkout set --no-cone '/app/' '/lib/' '/config/' '/engines/' '/ee/' '/*/app/' '/*/lib/' 2>/dev/null; } || echo "clone failed: $repo" >&2
done
pattern='def (self\.)?(timestamp_attributes_for_(create|update)|type_for_column|serialization_key|scope_prefix|controller_scope|controller_action_scope|scope_option_by_(controller_path|partial)|origin_trusted\?|sec_fetch_site_value|embed_authenticity_token\?|verified_query_request\?|distance_translation|append_option_tag|preload_link_href|read_attr|resolve_alias|mail_was_called\?|association_cache|implicit_persistence_transaction|primary_key_is_composite\?|autosave_belongs_to_association|schema_attributes|mapped_table|schema_context|current_schema_context|attribute_slots|abstract_ancestors|primary_key_definition|all_queries_scope|has_default_scope\?|has_json|has_delegated_json|default_order|this_(week|month|quarter|year)\?|datalist_tag|retry_on_handler|discard_on_handler|apply_pending_attribute_modifications)\b|scope :(default_order|has_json|schema_context|mapped_table|schema_attributes|all_queries_scope)\b|resources? :inbound_emails\b|\.(field_error_proc|default_formats|mb_chars|get_primary_key|yaml_encoder|symbol_column_to_string|default_scope_override)\b'
{
  for d in "$dir"/*/; do
    repo=$(basename "$d" | sed 's/__/\//')
    echo "## $repo $(git -C "$d" rev-parse HEAD)"
    git -C "$d" grep -nE "$pattern" -- '*.rb' '*.erb' '*.haml' '*.slim' 2>/dev/null | grep -vE "^(vendor|spec|test)/" | head -40
  done
} > "$here/corpus-hits.txt"
