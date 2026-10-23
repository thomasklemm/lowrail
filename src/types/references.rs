//! Read-only, bounded call-site search. Unresolved names are candidates, not callers.
use super::*;
use crate::facts::schema::split_location;
use ruby_prism::Visit;
use serde_json::{Value, json};
use std::collections::BTreeSet;

pub(super) fn callers(facts: &Facts, target: &str) -> Result<Value, String> {
    let (receiver, name, singleton) = target.rsplit_once('#').map(|(c, m)| (c, m, false))
        .or_else(|| target.rsplit_once('.').map(|(c, m)| (c, m, true)))
        .ok_or("expected Class#method or Class.method")?;
    let (_, wanted) = resolve(facts, receiver, name, singleton).ok_or("no boot method for target")?;
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
            found: &mut found, unresolved: &mut unresolved }.visit(&parsed.node());
    }
    Ok(json!({"available":true,"target":target,"callers":found,"unresolved":unresolved,
        "unavailable_sources":unavailable,
        "complete":false,"scope":"boot-indexed Ruby files; implicit/self/constant receivers outside blocks only; dynamic dispatch, templates and unindexed files are not exhaustive"}))
}

struct Calls<'a> {
    facts: &'a Facts,
    path: &'a str,
    source: &'a [u8],
    wanted: &'a Method,
    wanted_receiver: &'a str,
    name: &'a str,
    context: Option<(String, String, bool)>,
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
            let line = self.source[..loc.start() as usize].iter().filter(|&&b| b == b'\n').count() + 1;
            let column = self.source[..loc.start() as usize].iter().rposition(|&b| b == b'\n')
                .map_or(loc.start() as usize + 1, |p| loc.start() as usize - p);
            let site = json!({"path":self.path,"line":line,"column":column,
                "caller":self.context.as_ref().map(|(r, m, s)| key(r, m, *s))});
            if let Some((_, method)) = resolved {
                if receiver.as_ref().is_some_and(|(r, _)| r == self.wanted_receiver)
                    && method.owner == self.wanted.owner && method.name == self.wanted.name
                    && method.singleton == self.wanted.singleton {
                    self.found.push(site);
                }
            } else {
                self.unresolved.push(site);
            }
        }
        ruby_prism::visit_call_node(self, node);
    }

    fn visit_block_node(&mut self, node: &ruby_prism::BlockNode<'pr>) {
        let previous = self.context.take();
        ruby_prism::visit_block_node(self, node);
        self.context = previous;
    }
}
