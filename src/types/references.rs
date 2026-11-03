//! Read-only, bounded call-site search. Unresolved names are candidates, not callers.
use super::*;
use crate::facts::schema::split_location;
use ruby_prism::Visit;
use serde_json::{Value, json};
use std::collections::BTreeSet;

const ROUTE_HELPERS: &str = "Lowrail::RouteHelpers";

/// Named-route helpers live in an anonymous module ahead of Rails' UrlFor, so
/// boot facts carry no method for them; the route table does. `direct`
/// helpers have no route, only a method in the booted helper modules.
fn route_helper(facts: &Facts, receiver: &str, name: &str) -> bool {
    let Some(route) = name.strip_suffix("_path").or_else(|| name.strip_suffix("_url")) else { return false; };
    let helpers = ["Rails.application.routes.named_routes.path_helpers_module",
        "Rails.application.routes.named_routes.url_helpers_module"];
    (facts.routes.iter().any(|r| r.name.as_deref() == Some(route))
        || facts.modules.iter().any(|m| helpers.contains(&m.name.as_str()) && m.methods.iter().any(|m| m.name == name)))
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
    let files = app_files(Path::new(&facts.app_root).join("app").as_path());
    let mut found = Vec::new();
    let mut unresolved = Vec::new();
    let mut unavailable = Vec::new();
    for path in paths {
        let Ok(source) = std::fs::read(path) else { unavailable.push(path); continue; };
        let parsed = parser.parse(&source);
        if parsed.errors().next().is_some() { unavailable.push(path); continue; }
        Calls { facts, path, source: &source, wanted, wanted_receiver: receiver, name, context: None,
            lexical: None, nesting: Vec::new(), files: &files, blocks: Vec::new(), collectors: Vec::new(),
            found: &mut found, unresolved: &mut unresolved }.visit(&parsed.node());
    }
    Ok(json!({"available":true,"target":target,"callers":found,"unresolved":unresolved,
        "unavailable_sources":unavailable,
        "complete":false,"scope":"boot-indexed Ruby files; implicit/self receivers outside blocks, in Rails respond_to/format blocks and in blocks of core iterators with an explicit receiver; constant receivers with an unambiguous lexical lookup; module methods resolved through booted includers or extenders; dynamic dispatch, other blocks, templates and unindexed files are not exhaustive"}))
}

struct Calls<'a> {
    facts: &'a Facts,
    path: &'a str,
    source: &'a [u8],
    wanted: &'a Method,
    wanted_receiver: &'a str,
    name: &'a str,
    /// The receiver `self` currently denotes, cleared in blocks that may rebind it.
    context: Option<(String, String, bool)>,
    /// The enclosing def, which blocks do not change; constant lookup is lexical.
    lexical: Option<(String, String, bool)>,
    /// Lexically enclosing class/module names, innermost last.
    nesting: Vec<String>,
    /// Normalized app/ file paths, for constants Zeitwerk has not loaded yet.
    files: &'a BTreeSet<String>,
    /// Per enclosing call: how its block treats the caller's self.
    blocks: Vec<Block>,
    /// Block parameters bound to Rails' respond_to collectors.
    collectors: Vec<Vec<u8>>,
    found: &'a mut Vec<Value>,
    unresolved: &'a mut Vec<Value>,
}

#[derive(Clone, Copy, PartialEq)]
enum Block {
    /// The block may run with another self (instance_exec, DSLs).
    Rebinds,
    /// Core iterators yield normally; self stays the caller's.
    Keeps,
    /// Rails respond_to: kept self, and the block parameter collects formats.
    Collects,
}

/// Core methods that yield to their block normally. Only trusted with an
/// explicit non-self receiver, so an app's own DSL method of the same name
/// called on self is not mistaken for them.
const YIELDING: &[&str] = &["tap", "then", "yield_self", "each", "each_with_index", "each_with_object",
    "map", "flat_map", "collect", "select", "filter", "filter_map", "reject", "find", "detect", "sum",
    "gsub", "sub", "times", "each_slice", "group_by", "sort_by", "index_by", "min_by", "max_by", "partition"];

/// Relative `.rb` paths under app/*/ (and concerns), lowercased without
/// underscores, so acronym inflections cannot hide an autoloadable constant.
fn app_files(app: &Path) -> BTreeSet<String> {
    fn walk(dir: &Path, base: &Path, out: &mut BTreeSet<String>) {
        let Ok(entries) = std::fs::read_dir(dir) else { return; };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() { walk(&path, base, out); }
            else if let Some(rel) = path.strip_prefix(base).ok().and_then(|p| p.to_str())
                && let Some(rel) = rel.strip_suffix(".rb") {
                // Strip the root directory (app/models/...) and any concerns/ prefix.
                let rel = rel.split_once('/').map_or(rel, |(_, r)| r);
                for rel in [rel, rel.strip_prefix("concerns/").unwrap_or(rel)] {
                    out.insert(rel.to_lowercase().replace('_', ""));
                }
            }
        }
    }
    let mut out = BTreeSet::new();
    walk(app, app, &mut out);
    out
}

impl<'pr> Visit<'pr> for Calls<'_> {
    fn visit_class_node(&mut self, node: &ruby_prism::ClassNode<'pr>) {
        self.nest(node.constant_path());
        ruby_prism::visit_class_node(self, node);
        self.nesting.pop();
    }

    fn visit_module_node(&mut self, node: &ruby_prism::ModuleNode<'pr>) {
        self.nest(node.constant_path());
        ruby_prism::visit_module_node(self, node);
        self.nesting.pop();
    }

    fn visit_def_node(&mut self, node: &ruby_prism::DefNode<'pr>) {
        let line = self.source[..node.location().start() as usize].iter().filter(|&&b| b == b'\n').count() as u32 + 1;
        let contexts: BTreeSet<_> = self.facts.modules.iter().flat_map(|m| &m.methods)
            .filter(|m| m.def_name().as_bytes() == node.name().as_slice()
                && m.source_location.as_deref().and_then(split_location) == Some((self.path, line)))
            .map(|m| {
                let owner = m.owner.strip_prefix("#<Class:").and_then(|s| s.strip_suffix('>')).unwrap_or(&m.owner);
                (owner.to_owned(), m.name.clone(), m.singleton)
            }).collect();
        let previous = (self.context.take(), self.lexical.take());
        self.context = (contexts.len() == 1).then(|| contexts.into_iter().next().unwrap());
        self.lexical = self.context.clone();
        ruby_prism::visit_def_node(self, node);
        (self.context, self.lexical) = previous;
    }

    fn visit_call_node(&mut self, node: &ruby_prism::CallNode<'pr>) {
        if node.name().as_slice() == self.name.as_bytes() && let Some(loc) = node.message_loc() {
            let constant = node.receiver().is_some_and(|n| n.as_constant_read_node().is_some() || n.as_constant_path_node().is_some());
            let receiver = match node.receiver() {
                None => self.context.as_ref().map(|(r, _, s)| (r.clone(), *s)),
                Some(n) if n.as_self_node().is_some() => self.context.as_ref().map(|(r, _, s)| (r.clone(), *s)),
                Some(n) if constant => {
                    let source = String::from_utf8_lossy(n.location().as_slice());
                    let name = source.trim_start_matches("::").to_owned();
                    (source.starts_with("::") || (self.lexical.is_some() && self.unambiguous(&name))).then_some((name, true))
                }
                _ => None,
            };
            // A block does not change constant lookup or the enclosing def.
            let context = if constant { &self.lexical } else { &self.context };
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
                "caller":context.as_ref().map(|(r, m, s)| key(r, m, *s))});
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
                let same = method.owner == self.wanted.owner && method.name == self.wanted.name
                    && method.singleton == self.wanted.singleton;
                let (r, s) = receiver.as_ref().unwrap();
                if same && r == self.wanted_receiver {
                    self.found.push(site);
                } else if same && self.wanted.owner == self.wanted_receiver
                    && self.facts.modules.iter().any(|m| m.name == self.wanted_receiver && m.kind == "module") {
                    // A queried module method (a concern, a ClassMethods
                    // module) is called through each class that includes or
                    // extends it; report that class, never conflating classes
                    // that merely share an implementation elsewhere.
                    let mut site = site;
                    site["via"] = json!(if *s { format!("{r}.") } else { r.clone() });
                    self.found.push(site);
                }
            } else {
                self.unresolved.push(site);
            }
        }
        self.blocks.push(self.block(node));
        ruby_prism::visit_call_node(self, node);
        self.blocks.pop();
    }

    fn visit_block_node(&mut self, node: &ruby_prism::BlockNode<'pr>) {
        if self.blocks.last() == Some(&Block::Keeps) {
            let collectors = std::mem::take(&mut self.collectors);
            ruby_prism::visit_block_node(self, node);
            self.collectors = collectors;
            return;
        }
        if self.blocks.last() == Some(&Block::Collects) {
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
    fn block(&self, node: &ruby_prism::CallNode<'_>) -> Block {
        let collects = match node.receiver() {
            None => node.name().as_slice() == b"respond_to" && self.context.as_ref().is_some_and(|(r, _, s)|
                !*s && resolve(self.facts, r, "respond_to", false)
                    .is_some_and(|(_, m)| m.owner == "ActionController::MimeResponds")),
            Some(receiver) => receiver.as_local_variable_read_node()
                .is_some_and(|n| self.collectors.iter().any(|c| c.as_slice() == n.name().as_slice())),
        };
        if collects { Block::Collects }
        else if node.receiver().is_some_and(|r| r.as_self_node().is_none())
            && YIELDING.iter().any(|n| n.as_bytes() == node.name().as_slice()) { Block::Keeps }
        else { Block::Rebinds }
    }

    fn nest(&mut self, node: ruby_prism::Node<'_>) {
        let name = String::from_utf8_lossy(node.location().as_slice());
        let outer = self.nesting.last().filter(|_| !name.starts_with("::"));
        let name = name.trim_start_matches("::");
        self.nesting.push(outer.map_or_else(|| name.to_owned(), |o| format!("{o}::{name}")));
    }

    /// A relative constant names the top-level one only when no lexically
    /// enclosing scope, nor an ancestor of the innermost one, has (or can
    /// autoload) a constant of that name. Any doubt refuses.
    fn unambiguous(&self, name: &str) -> bool {
        let mut scopes: BTreeSet<String> = BTreeSet::new();
        for scope in self.nesting.iter().chain(self.lexical.iter().map(|(r, _, _)| r)) {
            let mut prefix = scope.as_str();
            loop {
                scopes.insert(prefix.to_owned());
                let Some((outer, _)) = prefix.rsplit_once("::") else { break; };
                prefix = outer;
            }
        }
        if let Some(inner) = self.nesting.last().or(self.lexical.as_ref().map(|(r, _, _)| r))
            && let Some(module) = self.facts.modules.iter().find(|m| &m.name == inner)
        {
            scopes.extend(module.ancestors.iter().filter(|a| !a.starts_with('#')).cloned());
        }
        scopes.remove("Object");
        let first = name.split("::").next().unwrap_or(name);
        !scopes.iter().any(|scope| {
            let candidate = format!("{scope}::{first}");
            self.facts.modules.iter().any(|m| m.name == candidate || m.name.starts_with(&format!("{candidate}::")))
                || { let file = candidate.replace("::", "/").to_lowercase().replace('_', "");
                    self.files.iter().any(|f| *f == file || f.starts_with(&format!("{file}/"))) }
        })
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
