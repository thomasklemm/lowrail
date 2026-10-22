//! Bounded source queries, not an LSP or a guess about dynamic receivers.
use super::*;
use crate::facts::schema::split_location;
use ruby_prism::Visit;
use serde_json::{Value, json};

pub(super) fn query(model: &TypeModel, facts: &Facts, path: &str, line: u64, column: u64) -> Result<Value, String> {
    let path = Path::new(&facts.app_root).join(path).canonicalize().map_err(|e| e.to_string())?;
    if !facts.in_app(&path.to_string_lossy()) { return Err("path must be inside the app".into()); }
    if line == 0 || column == 0 { return Err("line and byte column are one-based".into()); }
    let source = std::fs::read(&path).map_err(|e| e.to_string())?;
    let mut lines = source.split_inclusive(|&b| b == b'\n');
    let start = lines.by_ref().take((line - 1) as usize).map(<[u8]>::len).sum::<usize>();
    let row = lines.next().ok_or("line outside source")?;
    let col = usize::try_from(column - 1).map_err(|_| "column outside source")?;
    if col >= row.len() || row[col] == b'\n' { return Err("column outside source".into()); }
    let parser = crate::parser::Parser::for_runtime(&facts.ruby_description)?;
    let parsed = parser.parse(&source);
    if parsed.errors().next().is_some() { return Err("cannot query invalid Ruby".into()); }
    let mut cursor = Cursor { facts, source: &source, path: &path.to_string_lossy(), offset: start + col,
        context: None, target: None };
    cursor.visit(&parsed.node());
    let Some((receiver, name, singleton, arguments)) = cursor.target else {
        return Ok(json!({"available":false,"reason":"unsupported node, ambiguous context or dynamic receiver"}));
    };
    let target = key(&receiver, &name, singleton);
    let sig = model.get(&receiver, &name, singleton).cloned()
        .or_else(|| resolve(facts, &receiver, &name, singleton)
            .and_then(|(owner, method)| model.get(&owner.name, &method.name, method.singleton)).cloned())
        .or_else(|| rails::lookup(facts, &receiver, &name, singleton, arguments));
    let Some(sig) = sig else {
        return Ok(json!({"available":false,"target":target,"reason":"no type contract available"}));
    };
    let mut fact = sig.return_type.clone();
    if arguments.is_some() && fact.evidence == Evidence::ProvenBody { fact.evidence = Evidence::Static; }
    Ok(json!({"available":true,"path":path,"line":line,"column":column,"coordinate_encoding":"one-based UTF-8 bytes",
        "kind":if arguments.is_some() { "call_return" } else { "method_return" },
        "target":target,"signature":sig.signature(),"fact":fact,"proven_type":fact.proven_type(),
        "scope":"advisory current source plus boot lookup; not live execution certification"}))
}

struct Cursor<'a> {
    facts: &'a Facts,
    source: &'a [u8],
    path: &'a str,
    offset: usize,
    context: Option<(String, bool)>,
    // None arguments denotes a definition, Some denotes a call's argument shape.
    target: Option<(String, String, bool, Option<bool>)>,
}

impl Cursor<'_> {
    fn contains(&self, location: ruby_prism::Location<'_>) -> bool {
        (location.start() as usize..location.end() as usize).contains(&self.offset)
    }
}

impl<'pr> Visit<'pr> for Cursor<'_> {
    fn visit_def_node(&mut self, node: &ruby_prism::DefNode<'pr>) {
        if !self.contains(node.location()) { return; }
        let line = self.source[..node.location().start() as usize].iter().filter(|&&b| b == b'\n').count() as u32 + 1;
        let mut matches = self.facts.modules.iter().flat_map(|module|
            module.methods.iter().map(move |method| (module, method))).filter(|(_, method)|
                method.def_name().as_bytes() == node.name().as_slice()
                && method.source_location.as_deref().and_then(split_location) == Some((self.path, line)));
        let first = matches.next();
        self.context = first.filter(|_| matches.next().is_none()).map(|(module, method)| (module.name.clone(), method.singleton));
        if self.contains(node.name_loc()) {
            if let Some((receiver, singleton)) = &self.context {
                self.target = Some((receiver.clone(), String::from_utf8_lossy(node.name().as_slice()).into(), *singleton, None));
            }
        } else {
            ruby_prism::visit_def_node(self, node);
        }
        self.context = None;
    }

    fn visit_call_node(&mut self, node: &ruby_prism::CallNode<'pr>) {
        if node.message_loc().is_some_and(|location| self.contains(location)) && !node.is_safe_navigation()
            && node.block().is_none()
            && node.arguments().is_none_or(|args| args.arguments().iter().all(infer::argument))
        {
            let receiver = match node.receiver() {
                None => self.context.clone(),
                Some(n) if n.as_self_node().is_some() => self.context.clone(),
                Some(n) if n.as_constant_read_node().is_some() || n.as_constant_path_node().is_some() => {
                    let name = String::from_utf8_lossy(n.location().as_slice()).trim_start_matches("::").to_owned();
                    observed::constant(&name).then_some((name, true))
                }
                _ => None,
            };
            if let Some((receiver, singleton)) = receiver {
                self.target = Some((receiver, String::from_utf8_lossy(node.name().as_slice()).into(), singleton, Some(node.arguments().is_some())));
            }
        }
        ruby_prism::visit_call_node(self, node);
    }

    fn visit_block_node(&mut self, node: &ruby_prism::BlockNode<'pr>) {
        // instance_exec/class_eval and arbitrary yielded blocks may change self.
        let previous = self.context.take();
        ruby_prism::visit_block_node(self, node);
        self.context = previous;
    }
}
