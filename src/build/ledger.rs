//! Normalize pass diagnostics at the build boundary, without losing their
//! original explanation. Codes are documented in docs/FORMATS.md.
use serde_json::{Value, json};

pub fn normalize(mut entry: Value) -> Value {
    let fields = entry.as_object_mut().unwrap();
    let pass = fields["pass"].as_str().unwrap().to_string();
    let detail = fields.remove("outcome").unwrap().as_str().unwrap().to_string();
    let file = fields.remove("file");
    let template = fields.remove("template");
    let method = fields.remove("method");
    let helper = fields.remove("helper");
    fields.insert("target".into(), file.or(template).or(method.clone()).unwrap_or_else(|| json!(pass)));
    fields.insert("site".into(), helper.or(method).unwrap_or_else(|| json!("*")));
    fields.entry("line").or_insert(json!(0));
    fields.entry("copies").or_insert(json!(1));
    let lowered = matches!(detail.as_str(), "lowered" | "lowered (homogeneous results only)" |
        "eligible (tree checked at runtime)" | "eligible scoped reader");
    fields.insert("outcome".into(), json!(if lowered { "lowered" } else { "refused" }));
    fields.insert("reason".into(), json!(reason(&pass, &detail)));
    fields.insert("detail".into(), json!(detail));
    entry
}

fn reason(pass: &str, detail: &str) -> &'static str {
    match detail {
        "lowered" => return "lowered",
        "eligible (tree checked at runtime)" => return "runtime_tree",
        "eligible scoped reader" => return "scoped_reader",
        "lowered (homogeneous results only)" => return "homogeneous_results",
        "denylisted by verify --bisect" => return "denylisted",
        _ if detail.starts_with("declined:") => return "builder_error",
        _ if detail.starts_with("template requires method context") => return "template_context",
        _ if detail.starts_with("template source does not parse") => return "template_parse",
        _ => {}
    }
    // Match stable portions only: details can contain helper/model names,
    // file paths and oracle exceptions. Never make those part of a code.
    let rules: &[(&str, &str)] = match pass {
        "view/link_to" => &[
            ("unsupported arity", "arity"), ("splat or block argument", "arguments"),
            ("html options are not literal", "dynamic_options"),
            ("record class", "model_class"), ("not known as an Active Record model", "model_class"),
            ("url_for(", "record_url"), ("url is not a literal", "url_shape"),
            ("oracle result is not html_safe", "unsafe_html"), ("marker not found", "marker"),
            ("escaping probe mismatch", "escaping"), ("span lines", "multiline"),
            ("unresolved dependency", "dependency"), ("oracle:", "oracle_error"), ("probe:", "probe_error"),
        ],
        "route/path" => &[
            ("options hash argument", "options_hash"), ("splat or forwarded", "arguments"),
            ("explicit receiver", "explicit_receiver"), ("not inside an instance method", "context"),
            ("block given", "block"), ("positional argument(s)", "arity"),
            ("contains another route helper", "nested"), ("argument spans lines", "multiline"),
            ("specialized code would add lines", "multiline"), ("same lines", "reparse"),
            ("requirements or a glob", "non_optimized"), ("defaults set url options", "url_defaults"),
            ("not the route set", "overridden_helper"), ("block-backed direct/resolve", "block_helper"),
            ("unknown helper kind", "helper_kind"), ("no template", "template"),
            ("could not split", "template"), ("not found exactly once", "marker"),
            ("not plain ASCII", "template_encoding"), ("probe mismatch", "probe_mismatch"),
            ("probe:", "probe_error"), ("unresolved Rails dependency", "dependency"),
        ],
        "memo/uri_join" | "memo/sha256" => &[
            ("whole method lacks", "method_certificate"), ("no purity certificate for the whole call", "call_certificate"),
            ("request-bound controller", "request_bound"), ("block or safe navigation", "call_shape"),
            ("certified number of positional", "arity"), ("splat/keyword/forwarded", "arguments"),
            ("multiline call", "multiline"), ("activate refinements", "refinements"),
            ("nested memo", "nested"), ("regexp timeouts", "regexp_timeout"),
        ],
        "digest/file_memo" => &[
            ("refined gem source", "refinements"), ("multiline file digest", "multiline"),
            ("non-certified Digest version", "digest_version"), ("non-native digest class", "digest_class"),
            ("custom digest method owner", "method_owner"), ("custom path coercion", "path_coercion"),
            ("non-certified Digest file implementation", "file_implementation"),
            ("aliased digest/IO method", "method_alias"), ("non-native digest/IO method", "native_method"),
        ],
        "active_record/preload_plans" => &[
            ("missing reflection", "missing_reflection"), ("through association", "through"),
            ("polymorphic belongs_to", "polymorphic"), ("owner-dependent scope", "owner_scope"),
            ("non-certified scope type", "scope_type"), ("non-certified scope", "scope_certificate"),
            ("composite key", "composite_key"), ("abstract target", "abstract_target"),
            ("default scope", "default_scope"), ("custom reflection scope constructor", "reflection_constructor"),
            ("custom association constructor", "association_constructor"), ("custom scope constructor", "scope_constructor"),
            ("custom relation constructor", "relation_constructor"), ("STI target", "sti"),
            ("deprecated association", "deprecated"), ("non-certified ", "framework_implementation"),
        ],
        "active_record/instantiate" => &[
            ("custom _load_from_sql", "load_override"), ("custom instantiate_instance_of", "dispatch_override"),
            ("custom attributes_builder", "builder_override"), ("unaudited Rails implementation", "rails_implementation"),
            ("custom builder dependency", "builder_dependency"), ("unaudited schema context", "schema_context"),
        ],
        "active_record/ar_plans" => &[
            ("no scope", "no_scope"), ("owner-dependent scope", "owner_scope"),
            ("scope source unavailable", "scope_source"), ("scope source does not parse", "scope_parse"),
            ("scope lambda is not uniquely located", "scope_location"), ("scope parameters", "scope_parameters"),
            ("scope is not one fixed query chain", "scope_chain"), ("scope contains dynamic", "scope_dynamic"),
            ("through association", "through"), ("polymorphic belongs_to", "polymorphic"),
            ("association extensions", "extensions"), ("composite key", "composite_key"),
            ("default scope", "default_scope"), ("STI target", "sti"),
            ("custom owner attribute reader", "attribute_reader"), ("custom scope constructor", "scope_constructor"),
            ("custom reflection constructor", "reflection_constructor"), ("custom relation constructor", "relation_constructor"),
            ("unknown scope column or alias", "scope_column"), ("custom or enum scope type", "scope_type"),
            ("custom planning implementation", "planning_implementation"),
        ],
        "active_record/ar_plans_survey" => &[
            ("existing Rails StatementCache", "statement_cache"), ("not certified:", "query_certificate"),
            ("block (", "query_block"), ("WhereChain", "where_chain"), ("SQL fragment", "dynamic_predicate"),
            ("nonconstant/nested keys or splat", "predicate_keys"), ("array/range/nested predicate", "predicate_shape"),
            ("dynamic ", "dynamic_arguments"),
        ],
        _ => &[],
    };
    if let Some((_, code)) = rules.iter().find(|(text, _)| detail.contains(text)) { return code; }
    match pass {
        "memo/uri_join" | "memo/sha256" => "certificate",
        "route/path" => "oracle_error",
        _ => "unclassified",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shared_schema_keeps_explanations_copies_and_survey_metadata() {
        let refusal = normalize(json!({"template": "app/views/x.html.erb", "line": 12,
            "helper": "x_path", "pass": "route/path", "outcome": "options hash argument (Rails takes the non-optimized path)", "copies": 2}));
        assert_eq!(refusal, json!({"target": "app/views/x.html.erb", "line": 12, "site": "x_path", "pass": "route/path",
            "outcome": "refused", "reason": "options_hash", "detail": "options hash argument (Rails takes the non-optimized path)", "copies": 2}));
        let eligible = normalize(json!({"method": "Post#writer", "pass": "active_record/preload_plans", "outcome": "eligible (tree checked at runtime)"}));
        assert_eq!(eligible["outcome"], "lowered");
        assert_eq!(eligible["reason"], "runtime_tree");
        assert_eq!(eligible["target"], "Post#writer");
        assert_eq!(eligible["line"], 0);
        let survey = normalize(json!({"file": "app/models/post.rb", "line": 5, "helper": "where", "shape": "dynamic",
            "pass": "active_record/ar_plans_survey", "outcome": "not certified: implicit scope/model; lazy/scoping/metadata contract unproven"}));
        assert_eq!(survey["shape"], "dynamic");
        assert_eq!(survey["outcome"], "refused");
        assert_eq!(survey["reason"], "query_certificate");
        for pass in ["view/link_to", "route/path"] {
            for (detail, reason) in [
                ("template requires method context; diagnostic only, original handler retained", "template_context"),
                ("template source does not parse in method context: expected an expression", "template_parse"),
            ] {
                let entry = normalize(json!({"template": "app/views/layouts/application.html.erb", "helper": "compiled_body",
                    "pass": pass, "outcome": detail}));
                assert_eq!(entry["reason"], reason);
                assert_eq!(entry["outcome"], "refused");
            }
        }
    }
}
