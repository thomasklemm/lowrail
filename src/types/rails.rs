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
    if !(spec.version.starts_with("8.0.") || spec.version.starts_with("8.1.")) {
        return None;
    }
    let (path, _) = split_location(method.source_location.as_deref()?)?;
    (Path::new(path) == Path::new(&spec.path).join("lib").join(file)).then(|| {
        format!(
            "{gem} {} lib/{file}; boot owner {}",
            spec.version, method.owner
        )
    })
}

/// Lookup may use a generic relation receiver, whose element type comes from
/// schema/association inference, never from samples.
pub(super) fn lookup(
    facts: &Facts,
    receiver: &str,
    name: &str,
    singleton: bool,
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
    let (gem, file, result, params): (&str, &str, String, &[(&str, &str, &str)]) =
        match (method.owner.as_str(), name) {
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
            _ => return None,
        };
    let detail = source(facts, method, gem, file)?;
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
            if let Some(sig) = lookup(facts, &record.name, name, true) {
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
                        lookup(facts, &record.name, &method.name, false).unwrap_or_else(|| {
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
    for (receiver, singleton, names) in [
        (
            "ActiveRecord::Relation[Elem]",
            false,
            &[
                "order", "includes", "joins", "limit", "none", "find", "find_by", "find_by!",
            ][..],
        ),
        (
            "ActionController::Base",
            false,
            &["params", "head", "redirect_to"][..],
        ),
    ] {
        for name in names {
            if let Some(sig) = lookup(facts, receiver, name, singleton) {
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
