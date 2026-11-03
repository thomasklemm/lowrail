//! View inputs are contextual hints, not dominance or callback certificates.
use super::*;
use crate::facts::schema::Template;
use ruby_prism::{Node, Visit};
use serde_json::{Value, json};
use std::collections::BTreeSet;
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
        let (incoming, _) = incoming(model, facts, &parser, template);
        results.push(json!({"path":template.identifier,"virtual_path":template.virtual_path,
            "strict_locals":template.strict_locals,
            "controller_contexts":contexts(model, facts, template).into_iter()
                .map(|(action, ivars)| json!({"action":action,"exit_ivars":ivars})).collect::<Vec<_>>(),
            "incoming":incoming}));
    }
    Ok(json!({"available":true,"templates":results,"complete":false,
        "scope":"explicit literal partial renders and stock-path record renders in boot handler output; controller exit ivars are contextual hints only, not availability at render; callback, template effects and dynamic render dispatch are not modeled"}))
}

/// Explicit partial names, and `render record(s)` when the inferred model has
/// stock partial paths and no subclasses; other dynamically selected
/// templates stay unavailable rather than guessed. Returns each incoming
/// render as JSON and its typed locals.
fn incoming(model: &TypeModel, facts: &Facts, parser: &crate::parser::Parser, template: &Template)
    -> (Vec<Value>, Vec<BTreeMap<String, Type>>) {
    let (mut incoming, mut typed) = (Vec::new(), Vec::new());
    for parent in &facts.templates {
        if !fresh(parent) { continue; }
        let parsed = parser.parse(parent.code.as_bytes());
        if parsed.errors().next().is_some() { continue; }
        let contexts = contexts(model, facts, parent);
        for (action, ivars) in &contexts {
            Renders { model, facts, parent, target: template, action,
                ivars, incoming: &mut incoming, typed: &mut typed }.visit(&parsed.node());
        }
    }
    (incoming, typed)
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

/// `render` options that are not shorthand locals.
const RESERVED: &[&str] = &["partial", "collection", "object", "as", "layout", "formats", "variants", "status"];

struct Renders<'a> {
    model: &'a TypeModel,
    facts: &'a Facts,
    parent: &'a Template,
    target: &'a Template,
    action: &'a str,
    ivars: &'a BTreeMap<String, Type>,
    incoming: &'a mut Vec<Value>,
    typed: &'a mut Vec<BTreeMap<String, Type>>,
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

impl Renders<'_> {
    /// Directory, base name and `dir/_base` virtual path of a partial name,
    /// relative to the rendering template's directory when it has no slash.
    fn partial(&self, partial: &str) -> (String, String, String) {
        let parent_dir = self.parent.virtual_path.as_deref().and_then(|p| p.rsplit_once('/')).map(|(p, _)| p).unwrap_or("");
        let partial = if partial.contains('/') { partial.to_owned() } else { format!("{parent_dir}/{partial}") };
        let (dir, base) = partial.rsplit_once('/').unwrap_or(("", &partial));
        let base = base.trim_start_matches('_');
        (dir.to_owned(), base.to_owned(), format!("{dir}/_{base}"))
    }

    /// `render @article` / `render @articles`: Rails asks each record for
    /// its partial path, so require one booted model class without subclasses.
    fn implicit(&mut self, value: &Node<'_>) {
        let receiver = self.action.rsplit_once('#').map(|(r, _)| r).unwrap_or("");
        let ty = infer::value(value, self.facts, self.model, receiver, self.ivars);
        let collection = element_of(&ty.name);
        let class = collection.as_deref().unwrap_or(ty.name.trim_end_matches('?'));
        let Some(path) = self.facts.models.iter().find(|m| m.name == class).and_then(|m| m.partial_path.as_deref())
            else { return; };
        if self.facts.modules.iter().any(|m| m.kind == "class" && m.name != class && m.ancestors.iter().any(|a| a == class)) {
            return;
        }
        let Some((dir, base)) = path.rsplit_once('/') else { return; };
        if self.target.virtual_path.as_deref() != Some(&format!("{dir}/_{base}")) { return; }
        let mut element = ty.clone();
        element.name = class.to_owned();
        let mut locals = BTreeMap::new();
        if collection.is_some() {
            locals.insert(format!("{base}_counter"), Type::new("Integer", Source::RailsApi, "partial collection counter"));
            locals.insert(format!("{base}_iteration"), Type::new("untyped", Source::RailsApi, "partial iteration object; methods not modeled"));
        }
        locals.insert(base.to_owned(), element);
        let local_names: Vec<_> = locals.keys().collect();
        self.typed.push(locals.clone());
        self.incoming.push(json!({"from":self.parent.identifier,"action":self.action,
            "locals":locals,"local_names":local_names,"implicit_partial":path,
            "location_scope":"boot handler output, not original template line numbers"}));
    }
}

/// The model of a collection type, also when sampled arms name the same
/// model's relation classes (`M::ActiveRecord_AssociationRelation`, ...).
fn element_of(name: &str) -> Option<String> {
    let arms: Vec<&str> = match name.strip_prefix('(').and_then(|s| s.strip_suffix(')')) {
        // Generic arguments are model names here; a nested union refuses.
        Some(inner) if !inner.contains('(') => inner.split(" | ").collect(),
        Some(_) => return None,
        None => vec![name],
    };
    let mut models = arms.iter().map(|arm| {
        ["Array[", "ActiveRecord::Relation[", "ActiveRecord::Associations::CollectionProxy["].iter()
            .find_map(|prefix| arm.strip_prefix(prefix).and_then(|s| s.strip_suffix(']')))
            .or_else(|| ["::ActiveRecord_Relation", "::ActiveRecord_AssociationRelation", "::ActiveRecord_Associations_CollectionProxy"]
                .iter().find_map(|suffix| arm.strip_suffix(suffix)))
    });
    let first = models.next()??;
    models.all(|m| m == Some(first)).then(|| first.to_owned())
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
            if partial.is_none() && let Some(first) = args.first()
                && first.as_keyword_hash_node().is_none() && first.as_hash_node().is_none() {
                self.implicit(first);
            }
            // A partial layout: Rails' view `render` with an options hash
            // renders `layout:` as a partial when given a block, or beside
            // `partial:`; `render template:` layouts and a shorthand's
            // `layout:` local are not partials. It receives `locals:`.
            let hash = args.first().is_some_and(|a| a.as_keyword_hash_node().is_some() || a.as_hash_node().is_some());
            if hash && (node.block().is_some_and(|b| b.as_block_node().is_some()) || options.iter().any(|(k, _)| k == "partial"))
                && let Some(layout) = options.iter().find(|(k, _)| k == "layout").and_then(|(_, n)| literal(n))
                && self.target.virtual_path.as_deref() == Some(&self.partial(&layout).2) {
                let receiver = self.action.rsplit_once('#').map(|(r, _)| r).unwrap_or("");
                let locals: BTreeMap<_, _> = options.iter().filter(|(k, _)| k == "locals").flat_map(|(_, v)| pairs(v))
                    .map(|(name, node)| (name, infer::value(&node, self.facts, self.model, receiver, self.ivars))).collect();
                let local_names: Vec<_> = locals.keys().collect();
                self.typed.push(locals.clone());
                self.incoming.push(json!({"from":self.parent.identifier,"action":self.action,
                    "locals":locals,"local_names":local_names,"partial_layout":layout,
                    "location_scope":"boot handler output, not original template line numbers"}));
            }
            if let Some(partial) = partial {
                let (_, base, target) = self.partial(&partial);
                if self.target.virtual_path.as_deref() == Some(&target) {
                    let receiver = self.action.rsplit_once('#').map(|(r, _)| r).unwrap_or("");
                    let mut locals = BTreeMap::new();
                    for (name, value) in &options {
                        if name == "locals" {
                            for (name, value) in pairs(value) {
                                locals.insert(name, infer::value(&value, self.facts, self.model, receiver, self.ivars));
                            }
                        } else if shorthand.is_some() && !RESERVED.contains(&name.as_str()) {
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
                    self.typed.push(locals.clone());
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

/// Argument types that templates pass to app helper methods named in
/// `wanted`, with each incoming render's locals. A view's implicit self
/// includes the app helpers, so a call resolves to the one helper module
/// defining that name; any other module named *Helper(s) defining it, or the
/// base view class itself, makes the call ambiguous and it is skipped.
/// Locals the template assigns or binds as block parameters are dropped.
pub(super) fn helper_argument_sites(model: &TypeModel, facts: &Facts, wanted: &BTreeSet<String>)
    -> BTreeMap<String, Vec<(usize, Type, String)>> {
    let mut out: BTreeMap<String, Vec<(usize, Type, String)>> = BTreeMap::new();
    let Ok(parser) = crate::parser::Parser::for_runtime(&facts.ruby_description) else { return out; };
    // Conservative: no view ancestry is reconstructed. The name must have a
    // single defining module anywhere in the boot facts, an app helper.
    let owner = |name: &str| -> Option<String> {
        let [module] = definers(facts, name)?[..] else { return None; };
        (module.kind == "module" && module.const_source_location.as_deref()
            .is_some_and(|l| l.starts_with("app/helpers/") || l.contains("/app/helpers/"))).then(|| module.name.clone())
    };
    for template in &facts.templates {
        if !fresh(template) || !wanted.iter().any(|name| template.code.contains(name.as_str())) { continue; }
        let parsed = parser.parse(template.code.as_bytes());
        if parsed.errors().next().is_some() { continue; }
        let mut calls = HelperCalls { facts, wanted, calls: Vec::new(), bound: BTreeSet::new(), blocks: Vec::new(), opaque: 0 };
        calls.visit(&parsed.node());
        if calls.calls.is_empty() { continue; }
        let (_, contexts) = incoming(model, facts, &parser, template);
        let contexts = if contexts.is_empty() { vec![BTreeMap::new()] } else { contexts };
        for (name, arguments) in &calls.calls {
            let Some(module) = owner(name) else { continue; };
            for locals in &contexts {
                let locals: BTreeMap<_, _> = locals.iter().filter(|(n, _)| !calls.bound.contains(*n))
                    .map(|(n, t)| (n.clone(), t.clone())).collect();
                for (index, argument) in arguments.iter().enumerate() {
                    let parsed = parser.parse(argument.as_bytes());
                    let Some(node) = parsed.node().as_program_node().and_then(|p| p.statements().body().iter().next()) else { continue; };
                    let ty = infer::value(&node, facts, model, "", &locals);
                    out.entry(key(&module, name, false)).or_default()
                        .push((index, ty, format!("template {}", template.identifier)));
                }
            }
        }
    }
    out
}

/// Implicit-self calls of wanted names with only positional, non-block
/// arguments (kept as source text), and every name the template binds.
/// Calls inside a block are kept only when the block's method is a Rails or
/// Turbo view helper, which runs it through `capture` with the view as self.
struct HelperCalls<'a> {
    facts: &'a Facts,
    wanted: &'a BTreeSet<String>,
    calls: Vec<(String, Vec<String>)>,
    bound: BTreeSet<String>,
    /// Per enclosing call: whether its block keeps the view as self.
    blocks: Vec<bool>,
    /// Depth of enclosing blocks that may run with another self.
    opaque: usize,
}

impl HelperCalls<'_> {
    /// Every dumped module defining the name is a Rails or Turbo view helper
    /// whose method is defined in that gem, so the block runs through
    /// `capture` with the view as self. Any other definition refuses.
    fn captures(&self, node: &ruby_prism::CallNode<'_>) -> bool {
        if node.receiver().is_some() { return false; }
        let name = String::from_utf8_lossy(node.name().as_slice());
        let Some(modules) = definers(self.facts, &name) else { return false; };
        let gem = |m: &crate::facts::schema::Module, name: &str| m.methods.iter().filter(|d| d.name == name && !d.singleton).all(|d| {
            let at = d.source_location.as_deref().unwrap_or("");
            (m.name.starts_with("ActionView::Helpers::") && at.contains("/lib/action_view/helpers/"))
                || (m.name == "Turbo::FramesHelper" && at.contains("/app/helpers/turbo/frames_helper.rb"))
        });
        // Rails runs the block through `capture` (and `with_output_buffer`).
        // Any definer other than ActionView's own refuses: a module may be
        // included and a class inherited by a custom view class.
        let runner_safe = |runner: &str| definers(self.facts, runner).is_some_and(|modules| modules.iter().all(|m|
            m.name == "ActionView::Helpers::CaptureHelper" && gem(m, runner)));
        !modules.is_empty() && modules.iter().all(|m| gem(m, &name))
            && runner_safe("capture") && runner_safe("with_output_buffer")
    }
}

/// Every dumped module that defines an instance method of this name. None
/// when an unnamed ancestor defines it, or when the facts predate that record.
fn definers<'a>(facts: &'a Facts, name: &str) -> Option<Vec<&'a crate::facts::schema::Module>> {
    if facts.modules.iter().any(|m| m.anonymous_ancestor_methods.as_ref().is_none_or(|a| a.iter().any(|a| a == name))) {
        return None;
    }
    Some(facts.modules.iter().filter(|m| m.methods.iter().any(|d| d.name == name && !d.singleton)).collect())
}
impl<'pr> Visit<'pr> for HelperCalls<'_> {
    fn visit_call_node(&mut self, node: &ruby_prism::CallNode<'pr>) {
        let name = String::from_utf8_lossy(node.name().as_slice()).into_owned();
        if self.opaque == 0 && node.receiver().is_none() && self.wanted.contains(&name) && let Some(args) = node.arguments() {
            let arguments: Vec<_> = args.arguments().iter().filter(|a| a.as_keyword_hash_node().is_none())
                .map(|a| String::from_utf8_lossy(a.location().as_slice()).into_owned()).collect();
            if args.arguments().iter().all(|a| infer::argument(a)) {
                self.calls.push((name, arguments));
            }
        }
        self.blocks.push(self.captures(node));
        ruby_prism::visit_call_node(self, node);
        self.blocks.pop();
    }

    fn visit_block_node(&mut self, node: &ruby_prism::BlockNode<'pr>) {
        let opaque = self.blocks.last() != Some(&true);
        self.opaque += opaque as usize;
        ruby_prism::visit_block_node(self, node);
        self.opaque -= opaque as usize;
    }

    fn visit_local_variable_write_node(&mut self, node: &ruby_prism::LocalVariableWriteNode<'pr>) {
        self.bound.insert(String::from_utf8_lossy(node.name().as_slice()).into_owned());
        ruby_prism::visit_local_variable_write_node(self, node);
    }

    fn visit_required_parameter_node(&mut self, node: &ruby_prism::RequiredParameterNode<'pr>) {
        self.bound.insert(String::from_utf8_lossy(node.name().as_slice()).into_owned());
    }
}
