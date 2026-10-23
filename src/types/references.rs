//! Bounded source references, with boot-resolved dispatch separate from candidates.
use super::*;
use crate::facts::schema::split_location;
use ruby_prism::{Node, Visit};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;

pub(super) fn callers(model: &TypeModel, facts: &Facts, target: &str) -> Result<Value, String> {
    let (receiver, name, singleton) = target.rsplit_once('#').map(|(c, m)| (c, m, false))
        .or_else(|| target.rsplit_once('.').map(|(c, m)| (c, m, true)))
        .ok_or("expected Class#method or Class.method")?;
    let (_, wanted) = resolve(facts, receiver, name, singleton).ok_or("no boot method for target")?;
    let parser = crate::parser::Parser::for_runtime(&facts.ruby_description)?;
    let paths: BTreeSet<_> = facts.modules.iter().flat_map(|m|
        std::iter::once(m.const_source_location.as_deref()).chain(m.methods.iter().map(|m| m.source_location.as_deref())))
        .flatten().filter_map(split_location).map(|(p, _)| p)
        .filter(|p| facts.in_app(p) && p.ends_with(".rb")).collect();
    let mut calls = Calls { model, facts, path: String::new(), source: vec![], wanted, wanted_receiver: receiver,
        name, singleton, lexical: String::new(), context: None, found: vec![], unresolved: vec![] };
    let mut unavailable = Vec::new();
    for path in paths {
        let Ok(source) = std::fs::read(path) else { unavailable.push(path.to_owned()); continue; };
        let parsed = parser.parse(&source);
        if parsed.errors().next().is_some() { unavailable.push(path.to_owned()); continue; }
        calls.path = path.to_owned();
        calls.source = source.clone();
        calls.visit(&parsed.node());
    }
    for template in &facts.templates {
        let path = &template.identifier;
        let Ok(source) = std::fs::read(path) else { unavailable.push(path.clone()); continue; };
        if format!("{:x}", Sha256::digest(&source)) != template.source_sha256 {
            unavailable.push(path.clone()); continue;
        }
        let code = if path.ends_with(".erb") { erb_ruby(&source) }
            else if path.ends_with(".jbuilder") || path.ends_with(".ruby") { source.clone() }
            else { unavailable.push(path.clone()); continue; };
        let parsed = parser.parse(&code);
        if parsed.errors().next().is_some() { unavailable.push(path.clone()); continue; }
        calls.path = path.clone();
        calls.source = source;
        calls.visit(&parsed.node());
    }
    // A source reference can occur under several boot receiver alternatives.
    // Keep physical sites unique, without losing their resolution information.
    for sites in [&mut calls.found, &mut calls.unresolved] {
        sites.sort_by_key(Value::to_string);
        sites.dedup();
    }
    Ok(json!({"available":true,"target":target,"callers":calls.found,"unresolved":calls.unresolved,
        "unavailable_sources":unavailable,"complete":false,
        "summary":"Partial reference set, not a complete caller list. Dynamic dispatch, reflective method names, untyped receivers, custom block rebinding and unindexed sources can add callers. Callback/delegate/method references are potential dispatch edges, not guaranteed executions.",
        "scope":"boot-indexed Ruby declarations and fresh ERB/Jbuilder/Ruby templates; known dispatch and unresolved candidates kept separate"}))
}

struct Calls<'a> {
    model: &'a TypeModel,
    facts: &'a Facts,
    path: String,
    source: Vec<u8>,
    wanted: &'a Method,
    wanted_receiver: &'a str,
    name: &'a str,
    singleton: bool,
    lexical: String,
    context: Option<(String, String, bool)>,
    found: Vec<Value>,
    unresolved: Vec<Value>,
}

fn literal(node: &Node<'_>) -> Option<String> {
    node.as_symbol_node().map(|n| String::from_utf8_lossy(n.unescaped()).into_owned())
        .or_else(|| node.as_string_node().map(|n| String::from_utf8_lossy(n.unescaped()).into_owned()))
}

impl Calls<'_> {
    fn bindings(&self, receiver: &str, singleton: bool) -> Vec<(String, bool)> {
        let mut out = vec![(receiver.to_owned(), singleton)];
        if !singleton {
            for module in &self.facts.modules {
                if module.ancestors.iter().any(|a| a == receiver) { out.push((module.name.clone(), false)); }
                if module.singleton_ancestors.iter().any(|a| a == receiver) { out.push((module.name.clone(), true)); }
            }
        }
        out.sort(); out.dedup(); out
    }

    fn receiver(&self, node: Option<Node<'_>>) -> Vec<(String, bool)> {
        match node {
            None => self.context.as_ref().map(|(r, _, s)| self.bindings(r, *s)).unwrap_or_default(),
            Some(n) if n.as_self_node().is_some() => self.receiver(None),
            Some(n) if n.as_constant_read_node().is_some() || n.as_constant_path_node().is_some() => {
                let text = String::from_utf8_lossy(n.location().as_slice());
                if !self.lexical.contains("::") || text.starts_with("::") {
                    vec![(text.trim_start_matches("::").to_owned(), true)]
                } else { vec![] }
            }
            Some(n) => {
                let Some(call) = n.as_call_node() else { return vec![]; };
                if call.block().is_some() { return vec![]; }
                let name = String::from_utf8_lossy(call.name().as_slice());
                let mut out = Vec::new();
                for (receiver, singleton) in self.receiver(call.receiver()) {
                    if name == "class" && !singleton
                        && self.core_class(&receiver) {
                        out.push((receiver, true)); continue;
                    }
                    let ty = self.model.lookup(&key(&receiver, &name, singleton)).map(|s| s.return_type.clone())
                        .or_else(|| rails::lookup(self.facts, &receiver, &name, singleton,
                            Some(call.arguments().is_some())).map(|s| s.return_type))
                        .or_else(|| builtins::lookup(self.facts, &receiver, &name, singleton));
                    if let Some(ty) = ty.filter(|t| t.evidence != Evidence::Observed) {
                        let class = ty.name.trim_end_matches('?');
                        if observed::constant(class) && class != "NilClass" { out.push((class.to_owned(), false)); }
                    }
                }
                out.sort(); out.dedup(); out
            }
        }
    }

    fn core_class(&self, receiver: &str) -> bool {
        resolve(self.facts, receiver, "class", false).is_some_and(|(_, m)| m.owner == "Kernel"
            && m.source_location.as_deref().and_then(split_location).is_none_or(|(p, _)| !self.facts.in_app(p)))
    }

    fn record(&mut self, receivers: Vec<(String, bool)>, loc: ruby_prism::Location<'_>, kind: &str) {
        let line = self.source[..loc.start() as usize].iter().filter(|&&b| b == b'\n').count() + 1;
        let column = self.source[..loc.start() as usize].iter().rposition(|&b| b == b'\n')
            .map_or(loc.start() as usize + 1, |p| loc.start() as usize - p);
        let relative = Path::new(&self.path).strip_prefix(&self.facts.app_root).unwrap_or(Path::new(&self.path));
        let mut site = json!({"path":self.path,"line":line,"column":column,"location":format!("{}:{line}",relative.display()),
            "kind":kind,"caller":self.context.as_ref().map(|(r, m, s)| key(r, m, *s))});
        let mut matched = Vec::new();
        let mut unresolved = receivers.is_empty();
        for (receiver, singleton) in &receivers {
            let Some((_, method)) = resolve(self.facts, receiver, self.name, *singleton) else {
                unresolved = true; continue;
            };
            let same_receiver = receiver == self.wanted_receiver || (!self.singleton || self.name != "new")
                && self.facts.modules.iter().find(|m| m.name == *receiver).is_some_and(|m|
                    if *singleton { m.singleton_ancestors.contains(&format!("#<Class:{}>", self.wanted_receiver))
                        || m.singleton_ancestors.iter().any(|a| a == self.wanted_receiver) }
                    else { m.ancestors.iter().any(|a| a == self.wanted_receiver) });
            if same_receiver && *singleton == self.singleton && method.owner == self.wanted.owner
                && method.name == self.wanted.name && method.source_location == self.wanted.source_location {
                matched.push(key(receiver, self.name, *singleton));
            }
        }
        if !matched.is_empty() {
            site["dispatches"] = json!(matched);
            self.found.push(site);
        } else if unresolved {
            site["reason"] = json!("receiver/dispatch not statically resolved; a name match is not a verified caller");
            self.unresolved.push(site);
        }
    }

    fn nest(&mut self, node: Node<'_>) {
        let text = String::from_utf8_lossy(node.location().as_slice());
        self.lexical = if self.lexical.is_empty() || text.starts_with("::") {
            text.trim_start_matches("::").into()
        } else { format!("{}::{text}", self.lexical) };
    }
}

impl<'pr> Visit<'pr> for Calls<'_> {
    fn visit_class_node(&mut self, node: &ruby_prism::ClassNode<'pr>) {
        let previous = (self.lexical.clone(), self.context.take());
        self.nest(node.constant_path());
        ruby_prism::visit_class_node(self, node);
        (self.lexical, self.context) = previous;
    }

    fn visit_module_node(&mut self, node: &ruby_prism::ModuleNode<'pr>) {
        let previous = (self.lexical.clone(), self.context.take());
        self.nest(node.constant_path());
        ruby_prism::visit_module_node(self, node);
        (self.lexical, self.context) = previous;
    }

    fn visit_def_node(&mut self, node: &ruby_prism::DefNode<'pr>) {
        let line = self.source[..node.location().start() as usize].iter().filter(|&&b| b == b'\n').count() as u32 + 1;
        let contexts: BTreeSet<_> = self.facts.modules.iter().flat_map(|m| &m.methods)
            .filter(|m| m.def_name().as_bytes() == node.name().as_slice()
                && m.source_location.as_deref().and_then(split_location) == Some((self.path.as_str(), line)))
            .map(|m| {
                let owner = m.owner.strip_prefix("#<Class:").and_then(|s| s.strip_suffix('>')).unwrap_or(&m.owner);
                (owner.to_owned(), m.name.clone(), m.singleton)
            }).collect();
        let previous = self.context.take();
        self.context = (contexts.len() == 1).then(|| contexts.into_iter().next().unwrap());
        ruby_prism::visit_def_node(self, node);
        self.context = previous;
    }

    fn visit_call_node(&mut self, node: &ruby_prism::CallNode<'pr>) {
        let name = node.name();
        let operation = String::from_utf8_lossy(name.as_slice());
        let args: Vec<_> = node.arguments().map(|a| a.arguments().iter().collect()).unwrap_or_default();
        if name.as_slice() == self.name.as_bytes() && let Some(loc) = node.message_loc() {
            self.record(self.receiver(node.receiver()), loc, "call");
        }
        if matches!(name.as_slice(), b"send" | b"public_send" | b"__send__" | b"method" | b"public_method" | b"instance_method" | b"public_instance_method") {
            let reflected = args.first().and_then(literal);
            if reflected.as_deref().is_some_and(|n| n != self.name) {
                ruby_prism::visit_call_node(self, node);
                return;
            }
            let mut receivers: Vec<_> = self.receiver(node.receiver()).into_iter().filter(|(r, s)|
                reflected.is_some() && resolve(self.facts, r, &operation, *s).is_some_and(|(_, m)|
                    matches!(m.owner.as_str(), "Kernel" | "BasicObject" | "Module") && m.iseq_kind == "cfunc")).collect();
            if matches!(name.as_slice(), b"instance_method" | b"public_instance_method") {
                for (_, singleton) in &mut receivers { *singleton = false; }
            }
            self.record(receivers, args.first().map(|n| n.location()).unwrap_or(node.location()),
                if reflected.is_none() { "dynamic_reflection" }
                else if matches!(name.as_slice(), b"send" | b"public_send" | b"__send__") { "literal_send" } else { "method_reference" });
        }
        let mut callback_body = false;
        if self.context.is_none() && node.receiver().is_none() && !self.lexical.is_empty() {
            let callback = ["before_", "after_", "around_"].iter().filter_map(|p| operation.strip_prefix(p))
                .any(|event| matches!(event, "action" | "validation" | "save" | "create" | "update" | "destroy"
                    | "commit" | "rollback" | "initialize" | "find" | "touch" | "create_commit" | "update_commit" | "destroy_commit" | "save_commit"));
            if callback {
                callback_body = true;
                for arg in &args {
                    if literal(arg).as_deref() == Some(self.name) {
                        self.record(self.bindings(&self.lexical, false), arg.location(), "callback_reference");
                    }
                }
            }
            if name.as_slice() == b"delegate" && args.iter().any(|n| literal(n).as_deref() == Some(self.name)) {
                let destination = args.iter().filter_map(|n| n.as_keyword_hash_node())
                    .flat_map(|h| h.elements().iter()).filter_map(|n| n.as_assoc_node())
                    .find(|a| literal(&a.key()).as_deref() == Some("to")).and_then(|a| literal(&a.value()));
                let mut receivers = Vec::new();
                for (receiver, _) in self.bindings(&self.lexical, false) {
                    if destination.as_deref() == Some("class") && self.core_class(&receiver) {
                        receivers.push((receiver, true));
                    }
                    else if let Some(dest) = &destination
                        && let Some(sig) = self.model.lookup(&key(&receiver, dest, false))
                        && sig.return_type.evidence != Evidence::Observed
                    {
                        let name = sig.return_type.name.trim_end_matches('?');
                        if observed::constant(name) { receivers.push((name.to_owned(), false)); }
                    }
                }
                if let Some(arg) = args.iter().find(|n| literal(n).as_deref() == Some(self.name)) {
                    self.record(receivers, arg.location(), "delegate_reference");
                }
            }
        }
        let rebound = matches!(name.as_slice(), b"instance_eval" | b"instance_exec" | b"class_eval" | b"class_exec" | b"module_eval" | b"module_exec" | b"define_method");
        let previous = self.context.clone();
        if callback_body { self.context = Some((self.lexical.clone(), format!("<{operation}>"), false)); }
        if rebound { self.context = None; }
        let lexical = rebound.then(|| std::mem::take(&mut self.lexical));
        ruby_prism::visit_call_node(self, node);
        if let Some(lexical) = lexical { self.lexical = lexical; }
        self.context = previous;
    }
}

// Mask non-Ruby ERB bytes, retaining exact source coordinates. Generated handler
// offsets are not source offsets. Unsupported/custom handlers stay unavailable.
fn erb_ruby(source: &[u8]) -> Vec<u8> {
    let mut out: Vec<_> = source.iter().map(|b| if *b == b'\n' { b'\n' } else { b' ' }).collect();
    let mut offset = 0;
    while let Some(start) = source[offset..].windows(2).position(|w| w == b"<%") {
        let start = offset + start + 2;
        let Some(end) = source[start..].windows(2).position(|w| w == b"%>").map(|n| start + n) else { break; };
        if !matches!(source.get(start), Some(b'#' | b'%')) {
            let begin = start + usize::from(matches!(source.get(start), Some(b'=' | b'-')));
            let finish = end - usize::from(end > begin && source[end - 1] == b'-');
            out[begin..finish].copy_from_slice(&source[begin..finish]);
            out[finish] = b';';
        }
        offset = end + 2;
    }
    out
}
