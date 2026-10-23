//! Advisory declarations, never execution or proof of a Sorbet sig block.
use super::*;
use crate::facts::schema::split_location;
use ruby_prism::{Node, Visit};
use std::collections::BTreeSet;

#[derive(Clone)]
struct Declaration {
    scopes: Vec<String>,
    location: String,
    parameters: Vec<(String, String)>,
    types: BTreeMap<String, String>,
    result: String,
}

#[derive(Default)]
struct Index {
    path: String,
    source: Vec<u8>,
    scopes: Vec<String>,
    singleton: bool,
    declarations: BTreeMap<String, Vec<Declaration>>,
    aliases: BTreeMap<String, Vec<(String, Vec<String>, String)>>,
    constants: BTreeSet<String>,
}

fn text(node: &Node<'_>) -> String {
    String::from_utf8_lossy(node.location().as_slice()).into_owned()
}

fn block_body(node: Node<'_>) -> Option<Node<'_>> {
    let block = node.as_block_node()?;
    let body = block.body()?.as_statements_node()?;
    let mut nodes = body.body().iter();
    let first = nodes.next()?;
    nodes.next().is_none().then_some(first)
}

fn declared(node: Node<'_>) -> Option<(BTreeMap<String, String>, String)> {
    let mut node = node;
    let mut types = BTreeMap::new();
    let mut result = None;
    loop {
        let call = node.as_call_node()?;
        if call.block().is_some() || call.is_safe_navigation() {
            return None;
        }
        let args: Vec<_> = call
            .arguments()
            .map(|a| a.arguments().iter().collect())
            .unwrap_or_default();
        match call.name().as_slice() {
            b"returns" if args.len() == 1 && result.is_none() => result = Some(text(&args[0])),
            // void discards results; it does not constrain their Ruby value.
            b"void" if args.is_empty() && result.is_none() => result = Some("void".into()),
            b"params" if args.len() == 1 && types.is_empty() => {
                let hash = args[0].as_keyword_hash_node()?;
                for pair in hash.elements().iter() {
                    let pair = pair.as_assoc_node()?;
                    let key = pair.key().as_symbol_node()?;
                    types.insert(
                        String::from_utf8_lossy(key.unescaped()).into(),
                        text(&pair.value()),
                    );
                }
            }
            b"override" | b"overridable" | b"abstract" if args.is_empty() => {}
            b"checked" if args.len() == 1 && args[0].as_symbol_node().is_some() => {}
            _ => return None,
        }
        if let Some(receiver) = call.receiver() {
            node = receiver;
        } else {
            break;
        }
    }
    Some((types, result?))
}

fn parameters(def: &ruby_prism::DefNode<'_>) -> Option<Vec<(String, String)>> {
    let Some(params) = def.parameters() else {
        return Some(vec![]);
    };
    let mut out = Vec::new();
    let nodes = params
        .requireds()
        .iter()
        .chain(params.optionals().iter())
        .chain(params.rest())
        .chain(params.posts().iter())
        .chain(params.keywords().iter())
        .chain(params.keyword_rest())
        .chain(params.block());
    for node in nodes {
        let (kind, name) = if let Some(n) = node.as_required_parameter_node() {
            ("req", n.name())
        } else if let Some(n) = node.as_optional_parameter_node() {
            ("opt", n.name())
        } else if let Some(n) = node.as_rest_parameter_node() {
            ("rest", n.name()?)
        } else if let Some(n) = node.as_required_keyword_parameter_node() {
            ("keyreq", n.name())
        } else if let Some(n) = node.as_optional_keyword_parameter_node() {
            ("key", n.name())
        } else if let Some(n) = node.as_keyword_rest_parameter_node() {
            ("keyrest", n.name()?)
        } else if let Some(n) = node.as_block_parameter_node() {
            ("block", n.name()?)
        } else {
            return None;
        };
        out.push((kind.into(), String::from_utf8_lossy(name.as_slice()).into()));
    }
    Some(out)
}

impl Index {
    fn location(&self, node: &Node<'_>) -> String {
        let line = self.source[..node.location().start() as usize]
            .iter()
            .filter(|&&b| b == b'\n')
            .count()
            + 1;
        format!("{}:{line}", self.path)
    }
    fn nest(&mut self, name: String, body: Option<Node<'_>>) {
        let name = if name.starts_with("::") {
            name.trim_start_matches("::").into()
        } else if let Some(parent) = self.scopes.last() {
            format!("{parent}::{name}")
        } else {
            name
        };
        let previous = self.singleton;
        self.singleton = false;
        self.scopes.push(name);
        if let Some(body) = body {
            self.visit(&body);
        }
        self.scopes.pop();
        self.singleton = previous;
    }
}

impl<'pr> Visit<'pr> for Index {
    fn visit_class_node(&mut self, n: &ruby_prism::ClassNode<'pr>) {
        self.nest(text(&n.constant_path()), n.body());
    }
    fn visit_module_node(&mut self, n: &ruby_prism::ModuleNode<'pr>) {
        self.nest(text(&n.constant_path()), n.body());
    }
    fn visit_singleton_class_node(&mut self, n: &ruby_prism::SingletonClassNode<'pr>) {
        if n.expression().as_self_node().is_some() {
            let previous = self.singleton;
            self.singleton = true;
            if let Some(body) = n.body() {
                self.visit(&body);
            }
            self.singleton = previous;
        }
    }
    fn visit_statements_node(&mut self, n: &ruby_prism::StatementsNode<'pr>) {
        let mut pending = None;
        for node in n.body().iter() {
            if let Some(call) = node.as_call_node()
                && call.receiver().is_none()
                && call.name().as_slice() == b"sig"
            {
                pending = call
                    .block()
                    .and_then(block_body)
                    .and_then(declared)
                    .map(|(types, result)| (types, result, self.location(&node)));
                continue;
            }
            let def = node.as_def_node().or_else(|| {
                let call = node.as_call_node()?;
                if call.receiver().is_some()
                    || !matches!(
                        call.name().as_slice(),
                        b"private" | b"protected" | b"public"
                    )
                {
                    return None;
                }
                let args = call.arguments()?;
                if args.arguments().len() != 1 {
                    return None;
                }
                args.arguments().iter().next()?.as_def_node()
            });
            if let Some(def) = def {
                if let Some((types, result, location)) = pending.take()
                    && let Some(receiver) = self.scopes.last()
                    && def.receiver().is_none_or(|n| n.as_self_node().is_some())
                    && let Some(parameters) = parameters(&def)
                {
                    let id = key(
                        receiver,
                        &String::from_utf8_lossy(def.name().as_slice()),
                        self.singleton || def.receiver().is_some(),
                    );
                    self.declarations.entry(id).or_default().push(Declaration {
                        scopes: self.scopes.clone(),
                        location,
                        parameters,
                        types,
                        result,
                    });
                }
                continue;
            }
            pending = None;
            if let Some(assign) = node.as_constant_write_node() {
                let name = String::from_utf8_lossy(assign.name().as_slice());
                let name = self
                    .scopes
                    .last()
                    .map_or_else(|| name.to_string(), |p| format!("{p}::{name}"));
                self.constants.insert(name.clone());
                if let Some(call) = assign.value().as_call_node()
                    && call.name().as_slice() == b"type_alias"
                    && call.receiver().is_some_and(|r| text(&r) == "T")
                    && let Some(value) = call.block().and_then(block_body)
                {
                    let location = self.location(&node);
                    self.aliases.entry(name).or_default().push((
                        text(&value),
                        self.scopes.clone(),
                        location,
                    ));
                }
            } else if node.as_class_node().is_some()
                || node.as_module_node().is_some()
                || node.as_singleton_class_node().is_some()
            {
                self.visit(&node);
            }
            // No association through conditionals, arbitrary calls, or bodies.
        }
    }
}

fn type_name(
    node: &Node<'_>,
    scopes: &[String],
    index: &Index,
    facts: &Facts,
    provenance: &mut Vec<Provenance>,
    depth: usize,
    parser: &crate::parser::Parser,
) -> Option<String> {
    if depth > 12 {
        return None;
    }
    let raw = text(node);
    let mut contexts: Vec<_> = scopes.iter().rev().cloned().collect();
    if let Some(module) = scopes
        .last()
        .and_then(|name| facts.modules.iter().find(|m| &m.name == name))
    {
        contexts.extend(
            module
                .ancestors
                .iter()
                .filter(|n| !scopes.contains(n))
                .cloned(),
        );
    }
    if raw.starts_with("T.") || raw.starts_with("T::") {
        if contexts.iter().any(|scope| {
            let name = format!("{scope}::T");
            index.constants.contains(&name) || facts.modules.iter().any(|m| m.name == name)
        }) {
            return None;
        }
    }
    if raw == "T::Boolean" {
        return Some("bool".into());
    }
    if raw == "T.untyped" {
        return Some("untyped".into());
    }
    if node.as_constant_read_node().is_some() || node.as_constant_path_node().is_some() {
        let candidates: Vec<_> = if raw.starts_with("::") {
            vec![raw.trim_start_matches("::").to_string()]
        } else {
            contexts
                .iter()
                .map(|p| format!("{p}::{raw}"))
                .chain(std::iter::once(raw.clone()))
                .collect()
        };
        for name in candidates {
            // Once a qualified path's first constant binds, a missing nested
            // member must not fall through to a same-named outer namespace.
            let prefix = name.strip_suffix(&raw).unwrap_or("");
            let first = format!(
                "{prefix}{}",
                raw.trim_start_matches("::").split("::").next()?
            );
            let bound =
                index.constants.contains(&first) || facts.modules.iter().any(|m| m.name == first);
            if let Some(aliases) = index.aliases.get(&name) {
                if aliases.len() != 1 {
                    return None;
                }
                let (expr, scopes, location) = &aliases[0];
                provenance.push(Provenance {
                    source: Source::SorbetSig,
                    detail: format!("type alias {name} at {location}"),
                });
                return parse_type(expr, scopes, index, facts, provenance, depth + 1, parser);
            }
            if let Some(module) = facts.modules.iter().find(|m| m.name == name) {
                // A module constraint is not a concrete class return type in RBS.
                if module.kind != "class" {
                    return None;
                }
                return Some(match name.as_str() {
                    "NilClass" => "nil".into(),
                    "TrueClass" => "true".into(),
                    "FalseClass" => "false".into(),
                    "Array" => "Array[untyped]".into(),
                    "Hash" => "Hash[untyped, untyped]".into(),
                    "ActiveRecord::Relation" => "ActiveRecord::Relation[untyped]".into(),
                    _ => format!("::{name}"),
                });
            }
            if index.constants.contains(&name) || bound {
                return None;
            }
        }
        return None;
    }
    let call = node.as_call_node()?;
    let receiver = call.receiver().map(|n| text(&n))?;
    let args: Vec<_> = call
        .arguments()
        .map(|a| a.arguments().iter().collect())
        .unwrap_or_default();
    let name = call.name();
    if receiver == "T" && name.as_slice() == b"nilable" && args.len() == 1 {
        let ty = type_name(&args[0], scopes, index, facts, provenance, depth + 1, parser)?;
        return Some(nullable(&ty, true));
    }
    if receiver == "T" && name.as_slice() == b"any" && !args.is_empty() {
        let types: Option<Vec<_>> = args
            .iter()
            .map(|n| type_name(n, scopes, index, facts, provenance, depth + 1, parser))
            .collect();
        let types = types?;
        return Some(if types.iter().any(|t| t == "untyped") {
            "untyped".into()
        } else {
            format!("({})", types.join(" | "))
        });
    }
    if name.as_slice() == b"[]" {
        let (base, arity) = match receiver.as_str() {
            "T::Array" => ("Array", 1),
            "T::Hash" => ("Hash", 2),
            _ => return None,
        };
        if args.len() != arity {
            return None;
        }
        let types: Vec<_> = args
            .iter()
            .map(|n| {
                type_name(n, scopes, index, facts, provenance, depth + 1, parser)
                    .unwrap_or_else(|| "untyped".into())
            })
            .collect();
        return Some(format!("{base}[{}]", types.join(", ")));
    }
    None
}

fn parse_type(
    expr: &str,
    scopes: &[String],
    index: &Index,
    facts: &Facts,
    provenance: &mut Vec<Provenance>,
    depth: usize,
    parser: &crate::parser::Parser,
) -> Option<String> {
    let parsed = parser.parse(expr.as_bytes());
    if parsed.errors().next().is_some() {
        return None;
    }
    let program = parsed.node().as_program_node()?;
    let node = program.statements().body().iter().next()?;
    type_name(&node, scopes, index, facts, provenance, depth, parser)
}

fn files(dir: &Path, out: &mut BTreeSet<std::path::PathBuf>) {
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            let Ok(kind) = entry.file_type() else {
                continue;
            };
            if kind.is_dir() {
                files(&path, out);
            } else if kind.is_file() && path.extension().is_some_and(|x| x == "rb") {
                out.insert(path);
            }
        }
    }
}

pub(super) fn seed(facts: &Facts, model: &mut TypeModel, parser: &crate::parser::Parser) {
    let Some(gem) = facts.gems.iter().find(|g| g.name == "sorbet-runtime") else {
        return;
    };
    let mut paths = BTreeSet::new();
    files(&Path::new(&facts.app_root).join("app"), &mut paths);
    for module in &facts.modules {
        if let Some((path, _)) = module
            .const_source_location
            .as_deref()
            .and_then(split_location)
            && facts.in_app(path)
            && path.ends_with(".rb")
        {
            paths.insert(path.into());
        }
    }
    let mut index = Index::default();
    for path in paths {
        let Ok(bytes) = std::fs::read(&path) else {
            continue;
        };
        let parsed = parser.parse(&bytes);
        if parsed.errors().next().is_some() {
            model
                .diagnostics
                .push(format!("sorbet sig: cannot parse {}", path.display()));
            continue;
        }
        index.path = path.display().to_string();
        index.source = bytes.clone();
        index.visit(&parsed.node());
    }
    let mut recovered = BTreeMap::new();
    for module in &facts.modules {
        for method in &module.methods {
            let Some((path, _)) = method.source_location.as_deref().and_then(split_location) else {
                continue;
            };
            if !Path::new(path).starts_with(Path::new(&gem.path).join("lib/types/private/methods"))
                && method.sorbet_sig.is_none()
            {
                continue;
            }
            let id = key(&module.name, method.def_name(), method.singleton);
            let decl = if let Some(declarations) = index.declarations.get(&id) {
                if declarations.len() != 1 {
                    model
                        .diagnostics
                        .push(format!("sorbet sig: ambiguous declarations of {id}"));
                    continue;
                }
                declarations[0].clone()
            } else if let Some(sig) = &method.sorbet_sig {
                if sig.version != gem.version || !sig.version.starts_with("0.5.") {
                    continue;
                }
                let Some((path, _)) = split_location(&sig.source_location) else {
                    continue;
                };
                if !facts.in_app(path) {
                    continue;
                }
                Declaration {
                    scopes: vec![],
                    location: format!("{} (already-built boot registry)", sig.source_location),
                    parameters: sig
                        .parameters
                        .iter()
                        .filter_map(|p| Some((p.first()?.clone(), p.get(1)?.clone())))
                        .collect(),
                    types: sig.parameter_types.clone(),
                    result: sig.return_type.clone(),
                }
            } else {
                continue;
            };
            let ty = |expr: &str| {
                let mut provenance = vec![Provenance {
                    source: Source::SorbetSig,
                    detail: format!(
                        "sorbet sig {}: {expr}; sorbet-runtime {} boot method {}",
                        decl.location,
                        gem.version,
                        method.source_location.as_deref().unwrap()
                    ),
                }];
                let name = parse_type(expr, &decl.scopes, &index, facts, &mut provenance, 0, parser)
                    .unwrap_or_else(|| "untyped".into());
                Type {
                    name,
                    evidence: Evidence::Static,
                    provenance,
                    samples: BTreeMap::new(),
                    possible_nil: false,
                }
            };
            let parameters: Vec<_> = decl
                .parameters
                .iter()
                .map(|(kind, name)| Parameter {
                    kind: kind.clone(),
                    name: name.clone(),
                    ty: ty(decl
                        .types
                        .get(name)
                        .map(String::as_str)
                        .unwrap_or("T.untyped")),
                })
                .collect();
            recovered.insert(
                key(&module.name, &method.name, method.singleton),
                (parameters, ty(&decl.result)),
            );
        }
    }
    // Add declarations absent from body inference, then reuse the booted lookup
    // for inherited action/callback copies. Never infer an owner from its name.
    for (id, (_, result)) in &recovered {
        let (receiver, name, single) = index_method(id);
        model.insert(receiver, name, single, result.clone());
    }
    for sig in model.methods.values_mut() {
        let own = key(&sig.receiver, &sig.method, sig.singleton);
        let inherited = resolve(facts, &sig.receiver, &sig.method, sig.singleton)
            .map(|(owner, method)| key(&owner.name, &method.name, method.singleton));
        if let Some((params, result)) = recovered
            .get(&own)
            .or_else(|| inherited.as_ref().and_then(|id| recovered.get(id)))
        {
            sig.parameters = params.clone();
            sig.return_type = result.clone();
        }
    }
}

fn index_method(id: &str) -> (&str, &str, bool) {
    let pos = id.rfind(['#', '.']).unwrap();
    (&id[..pos], &id[pos + 1..], id.as_bytes()[pos] == b'.')
}
