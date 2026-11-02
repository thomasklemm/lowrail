//! Read-only, bounded call-site search. Unresolved names are candidates, not callers.
use super::*;
use crate::facts::schema::split_location;
use ruby_prism::Visit;
use serde_json::{Value, json};
use std::collections::BTreeSet;

const ROUTE_HELPERS: &str = "Lowrail::RouteHelpers";

/// Named-route helpers live in an anonymous module ahead of Rails' UrlFor, so
/// boot facts carry no method for them; the route table does.
fn route_helper(facts: &Facts, receiver: &str, name: &str) -> bool {
    let Some(route) = name.strip_suffix("_path").or_else(|| name.strip_suffix("_url")) else { return false; };
    facts.routes.iter().any(|r| r.name.as_deref() == Some(route))
        && facts.modules.iter().any(|m| m.name == receiver
            && m.ancestors.iter().any(|a| a == "ActionDispatch::Routing::UrlFor"))
}

pub(super) fn callers(facts: &Facts, target: &str) -> Result<Value, String> {
    let (receiver, name, singleton) = target.rsplit_once('#').map(|(c, m)| (c, m, false))
        .or_else(|| target.rsplit_once('.').map(|(c, m)| (c, m, true)))
        .ok_or("expected Class#method or Class.method")?;
    let route = Method { name: name.to_owned(), owner: ROUTE_HELPERS.into(), ..Default::default() };
    let wanted = match resolve(facts, receiver, name, singleton) {
        Some((_, method)) => method,
        None if !singleton && route_helper(facts, receiver, name) => &route,
        None => return Err("no boot method for target".into()),
    };
    let parser = crate::parser::Parser::for_runtime(&facts.ruby_description)?;
    let paths: BTreeSet<_> = facts.modules.iter().flat_map(|m| &m.methods)
        .filter_map(|m| m.source_location.as_deref().and_then(split_location))
        .map(|(p, _)| p).filter(|p| facts.in_app(p) && p.ends_with(".rb")).collect();
    let mut found = Vec::new();
    let mut unresolved = Vec::new();
    let mut unavailable = Vec::new();
    for path in paths {
        let Ok(source) = std::fs::read(path) else { unavailable.push(path); continue; };
        let parsed = parser.parse(&source);
        if parsed.errors().next().is_some() { unavailable.push(path); continue; }
        Calls { facts, path, source: &source, wanted, wanted_receiver: receiver, name, context: None,
            preserving: Vec::new(), collectors: Vec::new(),
            found: &mut found, unresolved: &mut unresolved }.visit(&parsed.node());
    }
    Ok(json!({"available":true,"target":target,"callers":found,"unresolved":unresolved,
        "unavailable_sources":unavailable,
        "complete":false,"scope":"boot-indexed Ruby files; implicit/self/constant receivers outside blocks, plus Rails respond_to/format blocks and module methods resolved through booted includers; dynamic dispatch, other blocks, templates and unindexed files are not exhaustive"}))
}

struct Calls<'a> {
    facts: &'a Facts,
    path: &'a str,
    source: &'a [u8],
    wanted: &'a Method,
    wanted_receiver: &'a str,
    name: &'a str,
    context: Option<(String, String, bool)>,
    /// Per enclosing call: whether its block runs with the caller's self.
    preserving: Vec<bool>,
    /// Block parameters bound to Rails' respond_to collectors.
    collectors: Vec<Vec<u8>>,
    found: &'a mut Vec<Value>,
    unresolved: &'a mut Vec<Value>,
}

impl<'pr> Visit<'pr> for Calls<'_> {
    fn visit_def_node(&mut self, node: &ruby_prism::DefNode<'pr>) {
        let line = self.source[..node.location().start() as usize].iter().filter(|&&b| b == b'\n').count() as u32 + 1;
        let contexts: BTreeSet<_> = self.facts.modules.iter().flat_map(|m| &m.methods)
            .filter(|m| m.def_name().as_bytes() == node.name().as_slice()
                && m.source_location.as_deref().and_then(split_location) == Some((self.path, line)))
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
        if node.name().as_slice() == self.name.as_bytes() && let Some(loc) = node.message_loc() {
            let receiver = match node.receiver() {
                None => self.context.as_ref().map(|(r, _, s)| (r.clone(), *s)),
                Some(n) if n.as_self_node().is_some() => self.context.as_ref().map(|(r, _, s)| (r.clone(), *s)),
                Some(n) if n.as_constant_read_node().is_some() || n.as_constant_path_node().is_some() => {
                    let name = String::from_utf8_lossy(n.location().as_slice()).trim_start_matches("::").to_owned();
                    // Relative constants inside a namespace require lexical lookup,
                    // which this index deliberately does not guess.
                    let nested = self.context.as_ref().is_some_and(|(r, _, _)| r.contains("::"));
                    ((self.context.is_some() && !nested) || n.location().as_slice().starts_with(b"::")).then_some((name, true))
                }
                _ => None,
            };
            let resolved = receiver.as_ref().and_then(|(r, s)| resolve(self.facts, r, self.name, *s));
            // A module method's implicit self is any booted class that includes
            // it. Report the site only for the queried class, with that class.
            let via = (resolved.is_none() && !receiver.as_ref().is_some_and(|(_, s)| *s)
                && node.receiver().is_none_or(|n| n.as_self_node().is_some()))
                .then(|| self.includer()).flatten();
            let line = self.source[..loc.start() as usize].iter().filter(|&&b| b == b'\n').count() + 1;
            let column = self.source[..loc.start() as usize].iter().rposition(|&b| b == b'\n')
                .map_or(loc.start() as usize + 1, |p| loc.start() as usize - p);
            let site = json!({"path":self.path,"line":line,"column":column,
                "caller":self.context.as_ref().map(|(r, m, s)| key(r, m, *s))});
            let route = resolved.is_none() && self.wanted.owner == ROUTE_HELPERS
                && node.receiver().is_none_or(|n| n.as_self_node().is_some())
                && receiver.as_ref().is_some_and(|(r, s)| !*s && r == self.wanted_receiver);
            if route {
                let mut site = site;
                site["route_helper"] = json!(true);
                self.found.push(site);
            } else if let Some(via) = via {
                let mut site = site;
                site["via"] = json!(via);
                self.found.push(site);
            } else if let Some((_, method)) = resolved {
                if receiver.as_ref().is_some_and(|(r, _)| r == self.wanted_receiver)
                    && method.owner == self.wanted.owner && method.name == self.wanted.name
                    && method.singleton == self.wanted.singleton {
                    self.found.push(site);
                }
            } else {
                self.unresolved.push(site);
            }
        }
        self.preserving.push(self.preserves_self(node));
        ruby_prism::visit_call_node(self, node);
        self.preserving.pop();
    }

    fn visit_block_node(&mut self, node: &ruby_prism::BlockNode<'pr>) {
        if self.preserving.last() == Some(&true) {
            // Rails stores these blocks and later calls them with `call`, so
            // their self is still the enclosing method's receiver.
            let parameter = node.parameters().and_then(|p| p.as_block_parameters_node())
                .and_then(|p| p.parameters()).and_then(|p| p.requireds().iter().next())
                .and_then(|p| p.as_required_parameter_node()).map(|p| p.name().as_slice().to_vec());
            let pushed = parameter.map(|p| self.collectors.push(p)).is_some();
            ruby_prism::visit_block_node(self, node);
            if pushed { self.collectors.pop(); }
            return;
        }
        let previous = self.context.take();
        let collectors = std::mem::take(&mut self.collectors);
        ruby_prism::visit_block_node(self, node);
        self.context = previous;
        self.collectors = collectors;
    }
}

impl Calls<'_> {
    fn preserves_self(&self, node: &ruby_prism::CallNode<'_>) -> bool {
        match node.receiver() {
            None => node.name().as_slice() == b"respond_to" && self.context.as_ref().is_some_and(|(r, _, s)|
                !*s && resolve(self.facts, r, "respond_to", false)
                    .is_some_and(|(_, m)| m.owner == "ActionController::MimeResponds")),
            Some(receiver) => receiver.as_local_variable_read_node()
                .is_some_and(|n| self.collectors.iter().any(|c| c.as_slice() == n.name().as_slice())),
        }
    }

    /// The queried class, when the current context is an instance method of a
    /// module that this class includes and the name resolves to the target there.
    fn includer(&self) -> Option<String> {
        let (module, _, false) = self.context.as_ref()? else { return None; };
        if self.wanted.singleton || !self.facts.modules.iter().any(|m| &m.name == module && m.kind == "module") {
            return None;
        }
        let class = self.facts.modules.iter().find(|m| m.name == self.wanted_receiver)?;
        if !class.ancestors.iter().any(|a| a == module) { return None; }
        let (_, method) = resolve(self.facts, &class.name, self.name, false)?;
        (method.owner == self.wanted.owner && method.name == self.wanted.name && !method.singleton)
            .then(|| class.name.clone())
    }
}
