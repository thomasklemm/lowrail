//! View inputs are contextual hints, not dominance or callback certificates.
use super::*;
use crate::facts::schema::Template;
use ruby_prism::{Node, Visit};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

fn fresh(template: &Template) -> bool {
    std::fs::read(&template.identifier).is_ok_and(|source|
        format!("{:x}", Sha256::digest(source)) == template.source_sha256)
}

pub(super) fn query(model: &TypeModel, facts: &Facts, path: &str) -> Result<Value, String> {
    let templates: Vec<_> = facts.templates.iter().filter(|t|
        t.identifier == path || t.virtual_path.as_deref() == Some(path)
        || Path::new(&t.identifier).strip_prefix(&facts.app_root).ok() == Some(Path::new(path))).collect();
    if templates.is_empty() { return Ok(json!({"available":false,"reason":"no booted template for path"})); }
    if templates.iter().any(|t| !fresh(t)) {
        return Ok(json!({"available":false,"reason":"template missing or changed since boot; materialize again"}));
    }
    let parser = crate::parser::Parser::for_runtime(&facts.ruby_description)?;
    let mut results = Vec::new();
    for template in templates {
        let mut incoming = Vec::new();
        // Explicit partial-name edges only. Object/collection dispatch and
        // dynamically selected templates stay unavailable rather than guessed.
        for parent in &facts.templates {
            if !fresh(parent) { continue; }
            let parsed = parser.parse(parent.code.as_bytes());
            if parsed.errors().next().is_some() { continue; }
            let contexts = contexts(model, facts, parent);
            for (action, ivars) in &contexts {
                Renders { model, facts, parent, target: template, action,
                    ivars, incoming: &mut incoming }.visit(&parsed.node());
            }
        }
        results.push(json!({"path":template.identifier,"virtual_path":template.virtual_path,
            "strict_locals":template.strict_locals,
            "controller_contexts":contexts(model, facts, template).into_iter()
                .map(|(action, ivars)| json!({"action":action,"exit_ivars":ivars})).collect::<Vec<_>>(),
            "incoming":incoming}));
    }
    Ok(json!({"available":true,"templates":results,"complete":false,
        "scope":"explicit literal partial renders in boot handler output; controller exit ivars are contextual hints only, not availability at render; callback, template effects and dynamic render dispatch are not modeled"}))
}

fn contexts(model: &TypeModel, facts: &Facts, template: &Template) -> Vec<(String, BTreeMap<String, Type>)> {
    let Some(path) = template.virtual_path.as_deref() else { return vec![(String::new(), BTreeMap::new())]; };
    let mut out = Vec::new();
    for route in &facts.routes {
        let (Some(controller), Some(action)) = (&route.controller, &route.action) else { continue; };
        if path != format!("{controller}/{action}") { continue; }
        let suffix = format!("/app/controllers/{controller}_controller.rb");
        for module in &facts.modules {
            if !module.const_source_location.as_deref().and_then(crate::facts::schema::split_location)
                .is_some_and(|(p, _)| p.ends_with(&suffix)) { continue; }
            if !facts.controllers.iter().any(|c| c.name == module.name && c.actions.contains(action)) { continue; }
            let target = key(&module.name, action, false);
            if out.iter().any(|(id, _)| id == &target) { continue; }
            let mut ivars = model.lookup(&target).map(|s| s.ivars.clone()).unwrap_or_default();
            // Queries run after observation merging; retain observed provenance
            // explicitly and never feed these hints back into static inference.
            for ty in ivars.values_mut() { if ty.evidence == Evidence::ProvenBody { ty.evidence = Evidence::Static; } }
            out.push((target, ivars));
        }
    }
    if out.is_empty() { out.push((String::new(), BTreeMap::new())); }
    out
}

struct Renders<'a> {
    model: &'a TypeModel,
    facts: &'a Facts,
    parent: &'a Template,
    target: &'a Template,
    action: &'a str,
    ivars: &'a BTreeMap<String, Type>,
    incoming: &'a mut Vec<Value>,
}

fn literal(node: &Node<'_>) -> Option<String> {
    node.as_string_node().map(|n| String::from_utf8_lossy(n.unescaped()).into_owned())
        .or_else(|| node.as_symbol_node().map(|n| String::from_utf8_lossy(n.unescaped()).into_owned()))
}

fn pairs<'pr>(node: &Node<'pr>) -> Vec<(String, Node<'pr>)> {
    let elements = if let Some(n) = node.as_keyword_hash_node() { n.elements() }
        else if let Some(n) = node.as_hash_node() { n.elements() } else { return vec![]; };
    elements.iter().filter_map(|n| {
        let pair = n.as_assoc_node()?;
        Some((literal(&pair.key())?, pair.value()))
    }).collect()
}

impl<'pr> Visit<'pr> for Renders<'_> {
    fn visit_call_node(&mut self, node: &ruby_prism::CallNode<'pr>) {
        if node.name().as_slice() == b"render" && node.receiver().is_none()
            && let Some(args) = node.arguments() {
            let args: Vec<_> = args.arguments().iter().collect();
            let options: Vec<_> = args.iter().flat_map(pairs).collect();
            let shorthand = args.first().and_then(literal);
            let partial = shorthand.clone()
                .or_else(|| options.iter().find(|(k, _)| k == "partial").and_then(|(_, n)| literal(n)));
            if let Some(partial) = partial {
                let parent_dir = self.parent.virtual_path.as_deref().and_then(|p| p.rsplit_once('/')).map(|(p, _)| p).unwrap_or("");
                let partial = if partial.contains('/') { partial } else { format!("{parent_dir}/{partial}") };
                let (dir, base) = partial.rsplit_once('/').unwrap_or(("", &partial));
                let target = format!("{dir}/_{}", base.trim_start_matches('_'));
                if self.target.virtual_path.as_deref() == Some(&target) {
                    let receiver = self.action.rsplit_once('#').map(|(r, _)| r).unwrap_or("");
                    let mut locals = BTreeMap::new();
                    for (name, value) in &options {
                        if name == "locals" {
                            for (name, value) in pairs(value) {
                                locals.insert(name, infer::value(&value, self.facts, self.model, receiver, self.ivars));
                            }
                        } else if shorthand.is_some() && !["partial", "collection", "object", "as", "layout", "formats", "variants", "status"].contains(&name.as_str()) {
                            locals.insert(name.clone(), infer::value(value, self.facts, self.model, receiver, self.ivars));
                        }
                    }
                    if let Some((_, value)) = options.iter().find(|(k, _)| k == "object") {
                        let name = options.iter().find(|(k, _)| k == "as").and_then(|(_, n)| literal(n))
                            .unwrap_or_else(|| base.trim_start_matches('_').into());
                        locals.insert(name, infer::value(value, self.facts, self.model, receiver, self.ivars));
                    }
                    let collection = options.iter().find(|(k, _)| k == "collection");
                    if collection.is_some() && !options.iter().any(|(k, _)| k == "object") {
                        let (_, value) = collection.unwrap();
                        let name = options.iter().find(|(k, _)| k == "as").and_then(|(_, n)| literal(n))
                            .unwrap_or_else(|| base.trim_start_matches('_').into());
                        let mut element = infer::value(value, self.facts, self.model, receiver, self.ivars);
                        element.name = ["Array[", "ActiveRecord::Relation[", "ActiveRecord::Associations::CollectionProxy["]
                            .iter().find_map(|prefix| element.name.strip_prefix(prefix).and_then(|s| s.strip_suffix(']')))
                            .unwrap_or("untyped").to_owned();
                        locals.insert(format!("{name}_counter"), Type::new("Integer", Source::RailsApi, "partial collection counter"));
                        locals.insert(format!("{name}_iteration"), Type::new("untyped", Source::RailsApi, "partial iteration object; methods not modeled"));
                        locals.insert(name, element);
                    }
                    let local_names: Vec<_> = locals.keys().collect();
                    self.incoming.push(json!({"from":self.parent.identifier,"action":self.action,
                        "locals":locals,"local_names":local_names,
                        "collection_unmodeled":collection.is_some_and(|_| options.iter().any(|(k, _)| k == "object")),
                        "location_scope":"boot handler output, not original template line numbers"}));
                }
            }
        }
        ruby_prism::visit_call_node(self, node);
    }
}
