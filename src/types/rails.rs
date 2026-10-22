//! A deliberately bounded real-Rails API catalog, not Roundhouse's replacement
//! runtime. Entries require a matching boot owner AND a source in the pinned
//! Rails gem. All results are advisory, including those propagated into bodies.
use super::*;
use crate::facts::schema::split_location;

fn signature(receiver: &str, name: &str, singleton: bool, ty: Type) -> Signature {
    Signature {
        receiver: receiver.into(),
        method: name.into(),
        singleton,
        parameters: vec![],
        return_type: ty,
        ivars: BTreeMap::new(),
        observation: None,
        roles: vec![],
        block_self: None,
    }
}

fn parameter(sig: &mut Signature, kind: &str, name: &str, ty: &str) {
    sig.parameters.push(Parameter {
        kind: kind.into(),
        name: name.into(),
        ty: Type::new(
            ty,
            sig.return_type.provenance[0].source.clone(),
            sig.return_type.provenance[0].detail.clone(),
        ),
    });
}

fn source(facts: &Facts, method: &Method, gem: &str, file: &str) -> Option<String> {
    let spec = facts.gems.iter().find(|g| g.name == gem)?;
    let supported = match gem {
        "activerecord" | "actionpack" | "actionview" => {
            spec.version.starts_with("8.0.") || spec.version.starts_with("8.1.")
        }
        "turbo-rails" => spec.version.starts_with("2.0."),
        "importmap-rails" => spec.version.starts_with("2.1.") || spec.version.starts_with("2.2."),
        _ => false,
    };
    if !supported {
        return None;
    }
    let (path, _) = split_location(method.source_location.as_deref()?)?;
    let file = if file.starts_with("app/") {
        file.into()
    } else {
        format!("lib/{file}")
    };
    (Path::new(path) == Path::new(&spec.path).join(&file))
        .then(|| format!("{gem} {} {file}; boot owner {}", spec.version, method.owner))
}

// General body inference tolerates partial non-model ancestor facts. A view
// contract cannot skip an anonymous helper that might shadow a return boundary.
fn view_method<'a>(facts: &'a Facts, receiver: &str, name: &str, singleton: bool) -> Option<&'a Method> {
    let (owner, method) = resolve(facts, receiver, name, singleton)?;
    let module = facts.modules.iter().find(|m| m.name == receiver)?;
    let ancestors = if singleton { &module.singleton_ancestors } else { &module.ancestors };
    for ancestor in ancestors {
        let named = if singleton {
            ancestor.strip_prefix("#<Class:").and_then(|n| n.strip_suffix('>')).unwrap_or(ancestor)
        } else { ancestor };
        if named == owner.name { break; }
        if ancestor.starts_with('#') && !facts.modules.iter().any(|m| m.name == named) {
            return None;
        }
    }
    Some(method)
}

/// Lookup may use a generic relation receiver, whose element type comes from
/// schema/association inference, never from samples.
/// `call_arguments` describes only fixed arity: Some(false) has zero arguments,
/// Some(true) has at least one (including nil), None requests the whole method.
/// Callers refuse splats/forwarding/blocks before using this specialization.
pub(super) fn lookup(
    facts: &Facts,
    receiver: &str,
    name: &str,
    singleton: bool,
    call_arguments: Option<bool>,
) -> Option<Signature> {
    let element = receiver
        .strip_prefix("ActiveRecord::Relation[")
        .or_else(|| receiver.strip_prefix("ActiveRecord::Associations::CollectionProxy["))
        .and_then(|s| s.strip_suffix(']'));
    let boot_receiver = if element.is_some() {
        "ActiveRecord::Relation"
    } else {
        receiver
    };
    let (owner, method) = resolve(facts, boot_receiver, name, singleton)?;
    if !singleton && name.ends_with('?') && owner.name == format!("{receiver}._enum_methods_module")
    {
        let detail = source(facts, method, "activerecord", "active_record/enum.rb")?;
        return Some(signature(
            receiver,
            name,
            false,
            Type::new("bool", Source::RailsApi, detail),
        ));
    }
    let record = element.unwrap_or(receiver);
    let relation = format!("ActiveRecord::Relation[{record}]");
    // View inputs keep their booted shapes without guessing value types.
    let boot_parameters: Vec<_> = method.parameters.iter().filter_map(|p| {
        Some((p.first()?.as_str(), p.get(1).map(String::as_str).unwrap_or("arg"), "untyped"))
    }).collect();
    let (gem, file, result, params): (&str, &str, String, &[(&str, &str, &str)]) =
        match (method.owner.as_str(), name) {
            // Normal-return contracts, not proofs about arbitrary mutated
            // buffers, conversion methods or blocks. tag(nil) is a builder;
            // invalid names may raise rather than returning a safe string.
            ("ActionView::Helpers::TagHelper", "tag") => (
                "actionview", "action_view/helpers/tag_helper.rb",
                match call_arguments {
                    Some(false) => "ActionView::Helpers::TagHelper::TagBuilder",
                    _ => "(ActiveSupport::SafeBuffer | ActionView::Helpers::TagHelper::TagBuilder)",
                }.into(),
                &boot_parameters,
            ),
            ("ActionView::Helpers::TagHelper", "content_tag" | "token_list" | "class_names" | "cdata_section" | "escape_once") => (
                "actionview", "action_view/helpers/tag_helper.rb", "ActiveSupport::SafeBuffer".into(), &boot_parameters,
            ),
            ("ActionView::Helpers::OutputSafetyHelper", "raw" | "safe_join" | "to_sentence") => (
                "actionview", "action_view/helpers/output_safety_helper.rb", "ActiveSupport::SafeBuffer".into(), &boot_parameters,
            ),
            ("ActionView::Helpers::CaptureHelper", "capture" | "content_for") => (
                "actionview", "action_view/helpers/capture_helper.rb", "ActiveSupport::SafeBuffer?".into(), &boot_parameters,
            ),
            ("ActionView::Helpers::CaptureHelper", "provide" | "content_for?") => (
                "actionview", "action_view/helpers/capture_helper.rb",
                if name == "provide" { "nil" } else { "bool" }.into(), &boot_parameters,
            ),
            ("ActiveRecord::Inheritance::ClassMethods", "new") => (
                "activerecord",
                "active_record/inheritance.rb",
                record.into(),
                &[
                    ("opt", "attributes", "untyped"),
                    ("block", "block", "untyped"),
                ],
            ),
            ("ActiveRecord::Core::ClassMethods", "find")
            | ("ActiveRecord::FinderMethods", "find") =>
            // This signature describes the block-free ID lookup form only.
            {
                (
                    "activerecord",
                    if method.owner == "ActiveRecord::FinderMethods" {
                        "active_record/relation/finder_methods.rb"
                    } else {
                        "active_record/core.rb"
                    },
                    format!("({record} | Array[{record}])"),
                    &[("rest", "ids", "untyped")],
                )
            }
            ("ActiveRecord::Core::ClassMethods", "find_by")
            | ("ActiveRecord::FinderMethods", "find_by" | "find_by!") => (
                "activerecord",
                if method.owner == "ActiveRecord::FinderMethods" {
                    "active_record/relation/finder_methods.rb"
                } else {
                    "active_record/core.rb"
                },
                nullable(record, name == "find_by"),
                &[("rest", "conditions", "untyped")],
            ),
            ("ActiveRecord::Querying", "where") | ("ActiveRecord::QueryMethods", "where") => (
                "activerecord",
                if method.owner == "ActiveRecord::Querying" { "active_record/querying.rb" }
                    else { "active_record/relation/query_methods.rb" },
                match call_arguments {
                    Some(true) => relation,
                    Some(false) => "ActiveRecord::QueryMethods::WhereChain".into(),
                    None => format!("({relation} | ActiveRecord::QueryMethods::WhereChain)"),
                },
                &[("rest", "args", "untyped")],
            ),
            ("ActiveRecord::Querying", "exists?") | ("ActiveRecord::FinderMethods", "exists?") => (
                "activerecord",
                if method.owner == "ActiveRecord::Querying" { "active_record/querying.rb" }
                    else { "active_record/relation/finder_methods.rb" },
                "bool".into(),
                &[("opt", "conditions", "untyped")],
            ),
            ("ActiveRecord::Querying", "order" | "includes" | "joins" | "limit" | "none")
            | ("ActiveRecord::QueryMethods", "order" | "includes" | "joins" | "limit" | "none") => {
                (
                    "activerecord",
                    if method.owner == "ActiveRecord::Querying" {
                        "active_record/querying.rb"
                    } else {
                        "active_record/relation/query_methods.rb"
                    },
                    relation,
                    match name {
                        "none" => &[],
                        "limit" => &[("req", "value", "untyped")],
                        _ => &[("rest", "args", "untyped")],
                    },
                )
            }
            ("ActiveRecord::Scoping::Named::ClassMethods", "all") => (
                "activerecord",
                "active_record/scoping/named.rb",
                relation,
                &[("key", "all_queries", "bool?")],
            ),
            ("ActiveRecord::AttributeMethods::PrimaryKey", "id") => {
                let model = facts.models.iter().find(|m| m.name == receiver)?;
                let column = model
                    .columns
                    .iter()
                    .find(|c| Some(c.name.as_str()) == model.primary_key.as_str())?;
                (
                    "activerecord",
                    "active_record/attribute_methods/primary_key.rb",
                    nullable(scalar(column.type_.as_deref()), true),
                    &[],
                )
            }
            ("ActionController::StrongParameters", "params") => (
                "actionpack",
                "action_controller/metal/strong_parameters.rb",
                "ActionController::Parameters".into(),
                &[],
            ),
            ("ActionController::Parameters", "permit") => (
                "actionpack",
                "action_controller/metal/strong_parameters.rb",
                "ActionController::Parameters".into(),
                &[("rest", "filters", "untyped")],
            ),
            ("ActionController::Head", "head") => (
                "actionpack",
                "action_controller/metal/head.rb",
                "true".into(),
                &[("req", "status", "untyped"), ("opt", "options", "untyped")],
            ),
            // redirect_to assigns the integer status last; render's return is NOT
            // a String contract (response_body= and render_to_body are extensible).
            ("ActionController::Redirecting", "redirect_to") => (
                "actionpack",
                "action_controller/metal/redirecting.rb",
                "Integer".into(),
                &[
                    ("opt", "options", "untyped"),
                    ("opt", "response_options", "untyped"),
                ],
            ),
            ("Turbo::Broadcastable::ClassMethods", "broadcasts_to") => (
                "turbo-rails",
                "app/models/concerns/turbo/broadcastable.rb",
                "untyped".into(),
                &[
                    ("req", "stream", "untyped"),
                    ("key", "inserts_by", "untyped"),
                    ("key", "target", "untyped"),
                    ("keyrest", "rendering", "untyped"),
                ],
            ),
            ("Turbo::Broadcastable", "broadcast_replace_to") => (
                "turbo-rails",
                "app/models/concerns/turbo/broadcastable.rb",
                "untyped".into(),
                &[
                    ("rest", "streamables", "untyped"),
                    ("keyrest", "rendering", "untyped"),
                ],
            ),
            ("Importmap::Freshness", "stale_when_importmap_changes") => (
                "importmap-rails",
                "app/controllers/importmap/freshness.rb",
                "untyped".into(),
                &[],
            ),
            _ => return None,
        };
    let detail = source(facts, method, gem, file)?;
    if gem == "actionview" {
        view_method(facts, receiver, name, singleton)?;
    }
    // Resolve dependent return boundaries on the actual receiver, including
    // included/prepended helpers, rather than on their defining Rails module.
    let dependencies: &[(&str, &str, &str)] = match (gem, name) {
        ("actionview", "tag" | "content_tag") => &[
            ("tag_builder", "ActionView::Helpers::TagHelper", "action_view/helpers/tag_helper.rb"),
        ],
        ("actionview", "token_list" | "class_names" | "to_sentence") => &[
            ("safe_join", "ActionView::Helpers::OutputSafetyHelper", "action_view/helpers/output_safety_helper.rb"),
        ],
        _ => &[],
    };
    for (dependency, expected_owner, expected_file) in dependencies {
        let callee = view_method(facts, receiver, dependency, singleton)?;
        if callee.owner != *expected_owner || source(facts, callee, gem, expected_file).is_none() {
            return None;
        }
    }
    let mut sig = signature(
        receiver,
        name,
        singleton,
        Type::new(result, Source::RailsApi, detail),
    );
    for (kind, name, ty) in params {
        parameter(&mut sig, kind, name, ty);
    }
    Some(sig)
}

pub(super) fn seed(facts: &Facts, model: &mut TypeModel) {
    for record in &facts.models {
        for name in ["new", "find", "find_by", "find_by!"] {
            if let Some(sig) = lookup(facts, &record.name, name, true, None) {
                model.methods.insert(key(&record.name, name, true), sig);
            }
        }
        // The boot census already records Rails' generated enum module. No
        // guessing labels, prefix/suffix options, or disabled methods from ASTs.
        if let Some(holder) = facts
            .modules
            .iter()
            .find(|m| m.name == format!("{}._enum_methods_module", record.name))
        {
            for method in &holder.methods {
                if method.singleton || !method.name.ends_with('?') {
                    continue;
                }
                if source(facts, method, "activerecord", "active_record/enum.rb").is_some() {
                    model.methods.insert(
                        key(&record.name, &method.name, false),
                        lookup(facts, &record.name, &method.name, false, None).unwrap_or_else(|| {
                            signature(
                                &record.name,
                                &method.name,
                                false,
                                Type::new(
                                    "untyped",
                                    Source::BootFact,
                                    "enum predicate lookup overridden or ambiguous",
                                ),
                            )
                        }),
                    );
                }
            }
        }
    }
}

/// Support members do not inflate per-app coverage. They use the same slot
/// renderer and provenance as app methods. A full Rails RBS collection remains
/// preferable; omit this support file when loading one.
pub(super) fn support(facts: &Facts) -> Vec<Signature> {
    let mut out = Vec::new();
    for record in &facts.models {
        for (name, singleton) in [("broadcasts_to", true), ("broadcast_replace_to", false)] {
            if let Some(sig) = lookup(facts, &record.name, name, singleton, None) {
                out.push(sig);
            }
        }
        for name in ["after_create_commit", "after_destroy_commit"] {
            if let Some((_, method)) = resolve(facts, &record.name, name, true)
                && method.owner == "ActiveRecord::Transactions::ClassMethods"
                && let Some(detail) = source(
                    facts,
                    method,
                    "activerecord",
                    "active_record/transactions.rb",
                )
            {
                let mut sig = signature(
                    &record.name,
                    name,
                    true,
                    Type::new("untyped", Source::RailsApi, detail),
                );
                for p in &method.parameters {
                    if let Some(kind) = p.first() {
                        parameter(
                            &mut sig,
                            kind,
                            p.get(1).map(String::as_str).unwrap_or("arg"),
                            "untyped",
                        );
                    }
                }
                if !sig.parameters.iter().any(|p| p.kind == "block") {
                    parameter(&mut sig, "block", "block", "untyped");
                }
                sig.block_self = Some(format!("::{}", record.name));
                out.push(sig);
            }
        }
    }
    if let Some(sig) = lookup(
        facts,
        "ActionController::Base",
        "stale_when_importmap_changes",
        true,
        None,
    ) {
        out.push(sig);
    }
    for (receiver, singleton, names) in [
        (
            "ActiveRecord::Relation[Elem]",
            false,
            &[
                "order", "includes", "joins", "limit", "none", "find", "find_by", "find_by!", "where", "exists?",
            ][..],
        ),
        (
            "ActionController::Base",
            false,
            &["params", "head", "redirect_to"][..],
        ),
        ("ActionController::Parameters", false, &["permit"][..]),
    ] {
        for name in names {
            if let Some(sig) = lookup(facts, receiver, name, singleton, None) {
                out.push(sig);
            }
        }
    }
    // These APIs have intentionally unknown results and permissive arguments.
    // Their booted parameter lists are evidence for shape, not value types.
    for (receiver, singleton, names) in [
        (
            "ActiveRecord::Base",
            true,
            &[
                "primary_abstract_class",
                "has_many",
                "belongs_to",
                "validates",
                "after_create_commit",
                "after_destroy_commit",
            ][..],
        ),
        (
            "ActionController::Base",
            true,
            &["before_action", "allow_browser"][..],
        ),
        (
            "ActionController::Base",
            false,
            &["render", "respond_to", "redirect_to"][..],
        ),
        (
            "ActionController::Parameters",
            false,
            // Retain a shape-only fallback when permit's typed catalog entry
            // refuses an unsupported version/source/owner above.
            &["expect", "require", "permit", "[]"][..],
        ),
    ] {
        for name in names {
            if out
                .iter()
                .any(|s| s.receiver == receiver && s.method == *name && s.singleton == singleton)
            {
                continue;
            }
            if let Some((_, method)) = resolve(facts, receiver, name, singleton) {
                let Some(location) = &method.source_location else {
                    continue;
                };
                let mut sig = signature(
                    receiver,
                    name,
                    singleton,
                    Type::new(
                        "untyped",
                        Source::BootFact,
                        format!("{} at {location}; value contract unavailable", method.owner),
                    ),
                );
                for p in &method.parameters {
                    if let Some(kind) = p.first() {
                        parameter(
                            &mut sig,
                            kind,
                            p.get(1).map(String::as_str).unwrap_or("arg"),
                            "untyped",
                        );
                    }
                }
                // respond_to yields without an explicit &block parameter.
                if *name == "respond_to"
                    && method.owner == "ActionController::MimeResponds"
                    && source(
                        facts,
                        method,
                        "actionpack",
                        "action_controller/metal/mime_responds.rb",
                    )
                    .is_some()
                {
                    parameter(&mut sig, "block", "block", "untyped");
                }
                out.push(sig);
            }
        }
    }
    out
}
