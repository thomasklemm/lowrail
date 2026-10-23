//! Deliberately small, fail-closed Prism body walker and bounded return fixpoint.
use super::*;
use crate::facts::schema::split_location;
use ruby_prism::{Node, Visit};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Debug)]
enum Expr {
    Unknown,
    Literal(&'static str),
    Self_,
    Constant(String),
    Call(Option<Box<Expr>>, String, bool, bool),
    Sequence(Vec<Expr>),
    Read(String),
    Write(String, Box<Expr>),
    Array(Vec<Expr>),
    Hash(Vec<(Expr, Expr)>),
    Interpolation(Vec<Expr>),
    Branch(Box<Expr>, Box<Expr>, Box<Expr>),
}

fn expression(node: Node<'_>) -> Expr {
    expression_ref(&node)
}

fn expression_ref(node: &Node<'_>) -> Expr {
    if node.as_string_node().is_some() {
        Expr::Literal("String")
    } else if node.as_symbol_node().is_some() {
        Expr::Literal("Symbol")
    } else if node.as_integer_node().is_some() {
        Expr::Literal("Integer")
    } else if node.as_float_node().is_some() {
        Expr::Literal("Float")
    } else if node.as_true_node().is_some() || node.as_false_node().is_some() {
        Expr::Literal("bool")
    } else if node.as_nil_node().is_some() {
        Expr::Literal("nil")
    } else if node.as_self_node().is_some() {
        Expr::Self_
    } else if node.as_constant_read_node().is_some() || node.as_constant_path_node().is_some() {
        Expr::Constant(
            String::from_utf8_lossy(node.location().as_slice())
                .trim_start_matches("::")
                .into(),
        )
    } else if let Some(n) = node.as_statements_node() {
        Expr::Sequence(n.body().iter().map(expression).collect())
    } else if let Some(n) = node.as_if_node() {
        Expr::Branch(Box::new(expression(n.predicate())), Box::new(statements(n.statements())),
            Box::new(n.subsequent().map(expression).unwrap_or(Expr::Literal("nil"))))
    } else if let Some(n) = node.as_unless_node() {
        Expr::Branch(Box::new(expression(n.predicate())), Box::new(statements(n.statements())),
            Box::new(n.else_clause().map(|n| statements(n.statements())).unwrap_or(Expr::Literal("nil"))))
    } else if let Some(n) = node.as_else_node() {
        statements(n.statements())
    } else if let Some(n) = node.as_interpolated_string_node() {
        Expr::Interpolation(n.parts().iter().map(expression).collect())
    } else if let Some(n) = node.as_embedded_statements_node() {
        statements(n.statements())
    } else if let Some(n) = node.as_embedded_variable_node() {
        expression(n.variable())
    } else if let Some(n) = node.as_local_variable_read_node() {
        Expr::Read(String::from_utf8_lossy(n.name().as_slice()).into())
    } else if let Some(n) = node.as_instance_variable_read_node() {
        Expr::Read(String::from_utf8_lossy(n.name().as_slice()).into())
    } else if let Some(n) = node.as_local_variable_write_node() {
        Expr::Write(
            String::from_utf8_lossy(n.name().as_slice()).into(),
            Box::new(expression(n.value())),
        )
    } else if let Some(n) = node.as_instance_variable_write_node() {
        Expr::Write(
            String::from_utf8_lossy(n.name().as_slice()).into(),
            Box::new(expression(n.value())),
        )
    } else if let Some(n) = node.as_array_node() {
        if n.elements().iter().all(argument) {
            Expr::Array(n.elements().iter().map(expression).collect())
        } else {
            Expr::Unknown
        }
    } else if let Some(n) = node.as_hash_node() {
        if n.elements().iter().all(|n| n.as_assoc_node().is_some_and(|a| argument(a.key()) && argument(a.value()))) {
            Expr::Hash(n.elements().iter().map(|n| {
                let pair = n.as_assoc_node().unwrap();
                (expression(pair.key()), expression(pair.value()))
            }).collect())
        } else {
            Expr::Unknown
        }
    } else if let Some(n) = node.as_call_node() {
        if n.block().is_none()
            && n.arguments().is_none_or(|a| a.arguments().iter().all(argument))
        {
            Expr::Call(
                n.receiver().map(|r| Box::new(expression(r))),
                String::from_utf8_lossy(n.name().as_slice()).into(),
                n.arguments().is_some(),
                n.is_safe_navigation(),
            )
        } else {
            Expr::Unknown
        }
    } else {
        // Never infer just the tail of a body with unsupported control flow.
        Expr::Unknown
    }
}

fn statements(node: Option<ruby_prism::StatementsNode<'_>>) -> Expr {
    node.map(|n| Expr::Sequence(n.body().iter().map(expression).collect())).unwrap_or(Expr::Literal("nil"))
}

fn method_body(node: Node<'_>) -> Expr {
    let Some(body) = node.as_statements_node() else { return expression(node); };
    let nodes: Vec<_> = body.body().iter().collect();
    let length = nodes.len();
    Expr::Sequence(nodes.into_iter().enumerate().map(|(index, node)| {
        // Only the method's final top-level return is an implicit tail. Never
        // accept a return in a branch, interpolation, argument or earlier row.
        if index + 1 == length && let Some(ret) = node.as_return_node() {
            return match ret.arguments() {
                None => Expr::Literal("nil"),
                Some(args) if args.arguments().len() == 1 => expression(args.arguments().iter().next().unwrap()),
                _ => Expr::Unknown,
            };
        }
        expression(node)
    }).collect())
}

// Only accept arguments without unsupported control flow (including a return
// nested inside a hash or another call). Values are NOT inferred from argument
// positions. Calls with blocks, splats, forwarding and safe navigation refuse.
pub(super) fn argument(node: Node<'_>) -> bool {
    if node.as_string_node().is_some() || node.as_symbol_node().is_some()
        || node.as_integer_node().is_some() || node.as_float_node().is_some()
        || node.as_true_node().is_some() || node.as_false_node().is_some()
        || node.as_nil_node().is_some() || node.as_self_node().is_some()
        || node.as_constant_read_node().is_some()
        || (node.as_constant_path_node().is_some()
            && observed::constant(String::from_utf8_lossy(node.location().as_slice()).trim_start_matches("::")))
        || node.as_local_variable_read_node().is_some() || node.as_instance_variable_read_node().is_some()
    { return true; }
    if let Some(string) = node.as_interpolated_string_node() {
        return string.parts().iter().all(argument);
    }
    if let Some(part) = node.as_embedded_statements_node() {
        return part.statements().is_none_or(|n| n.body().iter().all(argument));
    }
    if let Some(part) = node.as_embedded_variable_node() { return argument(part.variable()); }
    if let Some(array) = node.as_array_node() {
        return array.elements().iter().all(argument);
    }
    if let Some(call) = node.as_call_node() {
        return call.block().is_none() && !call.is_safe_navigation()
            && call.receiver().is_none_or(argument)
            && call.arguments().is_none_or(|a| a.arguments().iter().all(argument));
    }
    let elements = if let Some(hash) = node.as_hash_node() { hash.elements() }
        else if let Some(hash) = node.as_keyword_hash_node() { hash.elements() }
        else { return false; };
    elements.iter().all(|n| n.as_assoc_node().is_some_and(|a| argument(a.key()) && argument(a.value())))
}

#[derive(Default)]
struct Index {
    defs: BTreeMap<(u32, String), Expr>,
    scopes: BTreeSet<(String, String)>,
    enums: BTreeSet<(String, String)>,
    source: Vec<u8>,
    nesting: String,
}

impl<'pr> Visit<'pr> for Index {
    fn visit_class_node(&mut self, n: &ruby_prism::ClassNode<'pr>) {
        let previous = self.nesting.clone();
        self.nest(n.constant_path());
        ruby_prism::visit_class_node(self, n);
        self.nesting = previous;
    }

    fn visit_module_node(&mut self, n: &ruby_prism::ModuleNode<'pr>) {
        let previous = self.nesting.clone();
        self.nest(n.constant_path());
        ruby_prism::visit_module_node(self, n);
        self.nesting = previous;
    }

    fn visit_def_node(&mut self, n: &ruby_prism::DefNode<'pr>) {
        let line = self.source[..n.location().start() as usize]
            .iter()
            .filter(|b| **b == b'\n')
            .count() as u32
            + 1;
        self.defs.insert(
            (line, String::from_utf8_lossy(n.name().as_slice()).into()),
            n.body().map(method_body).unwrap_or(Expr::Literal("nil")),
        );
        // Do not mistake macro calls inside method bodies for declarations.
    }

    fn visit_call_node(&mut self, n: &ruby_prism::CallNode<'pr>) {
        let name = n.name();
        if n.receiver().is_none()
            && matches!(name.as_slice(), b"scope" | b"enum")
            && let Some(args) = n.arguments()
            && let Some(symbol) = args
                .arguments()
                .iter()
                .next()
                .and_then(|n| n.as_symbol_node())
        {
            let set = if name.as_slice() == b"scope" {
                &mut self.scopes
            } else {
                &mut self.enums
            };
            set.insert((
                self.nesting.clone(),
                String::from_utf8_lossy(symbol.unescaped()).into(),
            ));
        }
        ruby_prism::visit_call_node(self, n);
    }
}

impl Index {
    fn nest(&mut self, node: Node<'_>) {
        let name = String::from_utf8_lossy(node.location().as_slice());
        self.nesting = if self.nesting.is_empty() || name.starts_with("::") {
            name.trim_start_matches("::").into()
        } else {
            format!("{}::{name}", self.nesting)
        };
    }

    fn load(path: &str, diagnostics: &mut Vec<String>, parser: &crate::parser::Parser) -> Self {
        let mut index = Index::default();
        match std::fs::read(path) {
            Ok(source) => {
                let parsed = parser.parse(&source);
                if parsed.errors().next().is_none() {
                    index.source = source.clone();
                    index.visit(&parsed.node());
                } else {
                    diagnostics.push(format!("cannot infer from invalid Ruby: {path}"));
                }
            }
            Err(e) => diagnostics.push(format!("cannot read {path}: {e}")),
        }
        index
    }
}

pub(super) fn analyze(facts: &Facts, model: &mut TypeModel, parser: &crate::parser::Parser) {
    // Template methods keep the template's source location, not a Ruby file.
    // Their handler output is a different program with different line offsets;
    // do not diagnose raw ERB/JS as invalid Ruby or infer bodies from it.
    let templates: BTreeSet<&str> = facts
        .templates
        .iter()
        .map(|t| t.identifier.as_str())
        .collect();
    let mut indexes = BTreeMap::new();
    let mut bodies = BTreeMap::new();
    for module in &facts.modules {
        if let Some((path, _)) = module
            .const_source_location
            .as_deref()
            .and_then(split_location)
            && facts.in_app(path)
            && !templates.contains(path)
        {
            indexes
                .entry(path.to_owned())
                .or_insert_with(|| Index::load(path, &mut model.diagnostics, parser));
        }
    }
    for module in &facts.modules {
        for method in &module.methods {
            let Some((path, line)) = method.source_location.as_deref().and_then(split_location)
            else {
                continue;
            };
            if !facts.in_app(path) || templates.contains(path) {
                continue;
            }
            let index = indexes
                .entry(path.to_owned())
                .or_insert_with(|| Index::load(path, &mut model.diagnostics, parser));
            if let Some(body) = index.defs.get(&(line, method.def_name().to_owned())) {
                let id = key(&module.name, &method.name, method.singleton);
                let sig = model.insert(
                    &module.name,
                    &method.name,
                    method.singleton,
                    Type::new(
                        "untyped",
                        Source::BootFact,
                        format!("method at {path}:{line}"),
                    ),
                );
                sig.return_type = Type::new(
                    "untyped",
                    Source::BootFact,
                    format!("body at {path}:{line}"),
                );
                bodies.insert(id, (body.clone(), format!("{path}:{line}")));
            }
        }
    }
    // Enum methods are generated in Rails rather than at the declaration. Only
    // use declarations from the model's own constant source file.
    for record in &facts.models {
        let path = facts
            .modules
            .iter()
            .find(|m| m.name == record.name)
            .and_then(|m| m.const_source_location.as_deref())
            .and_then(split_location)
            .map(|(p, _)| p);
        if let Some(index) = path.and_then(|p| indexes.get(p)) {
            for (_, name) in index
                .enums
                .iter()
                .filter(|(class, _)| class == &record.name)
            {
                let members = std::iter::once(name).chain(
                    record
                        .attribute_aliases
                        .iter()
                        .filter(|(_, original)| *original == name)
                        .map(|(alias, _)| alias),
                );
                for member in members {
                    if let Some(sig) = model.methods.get_mut(&key(&record.name, member, false)) {
                        sig.return_type = Type::new(
                            "String?",
                            Source::Inference,
                            format!("{}.enum {name}", record.name),
                        );
                    }
                }
            }
            for (_, name) in index
                .scopes
                .iter()
                .filter(|(class, _)| class == &record.name)
            {
                if resolve(facts, &record.name, name, true).is_some() {
                    model.insert(
                        &record.name,
                        name,
                        true,
                        Type::new(
                            format!("ActiveRecord::Relation[{}]", record.name),
                            Source::Inference,
                            format!("booted scope {}.{name}", record.name),
                        ),
                    );
                }
            }
        }
    }
    sorbet::seed(facts, model, parser);
    // Boot parameters and ownership override catalog guesses, including custom
    // readers. Resolve ancestor methods for model accessors as well.
    let ids: Vec<_> = model.methods.keys().cloned().collect();
    for id in ids {
        let sig = &model.methods[&id];
        if sig.return_type.provenance.iter().any(|p| p.source == Source::SorbetSig) {
            // A declaration is advisory even if its source body is a literal.
            bodies.remove(&id);
            continue;
        }
        if let Some((owner, method)) = resolve(facts, &sig.receiver, &sig.method, sig.singleton) {
            let own_key = key(&owner.name, &method.name, method.singleton);
            let body = bodies.get(&own_key).cloned();
            let sig = model.methods.get_mut(&id).unwrap();
            let catalog = rails::lookup(facts, &sig.receiver, &sig.method, sig.singleton, None);
            sig.parameters = method
                .parameters
                .iter()
                .filter_map(|p| {
                    let kind = p.first()?;
                    Some(Parameter {
                        kind: kind.clone(),
                        name: p.get(1).cloned().unwrap_or_else(|| "arg".into()),
                        ty: Type::new("untyped", Source::BootFact, format!("parameters of {id}")),
                    })
                })
                .collect();
            if let Some(catalog) = &catalog {
                sig.parameters = catalog.parameters.clone();
            }
            if let Some(body) = body {
                sig.return_type =
                    Type::new("untyped", Source::BootFact, format!("custom body of {id}"));
                bodies.insert(id, body);
            } else if let Some(catalog) = catalog {
                sig.return_type = catalog.return_type;
            } else {
                let generated = method.owner.ends_with("::GeneratedAttributeMethods")
                    || method.owner.ends_with("::GeneratedAssociationMethods");
                let query = sig.singleton && method.owner.starts_with("ActiveRecord::");
                let scope = sig.singleton
                    && method.owner == format!("#<Class:{}>", sig.receiver)
                    && sig.return_type.provenance.iter().any(|p| {
                        p.detail == format!("booted scope {}.{}", sig.receiver, sig.method)
                    });
                if !generated && !query && !scope {
                    sig.return_type = Type::new(
                        "untyped",
                        Source::BootFact,
                        format!("unmodeled boot owner {} for {id}", method.owner),
                    );
                    bodies.remove(&id);
                }
            }
        } else if !sig.singleton
            && sig.receiver != "Lowrail::RouteHelpers"
            && !sig.method.ends_with('=')
        {
            model.methods.get_mut(&id).unwrap().parameters.clear();
        }
    }
    for _ in 0..8 {
        let mut changes = Vec::new();
        for (id, (expr, location)) in &bodies {
            let sig = &model.methods[id];
            let mut locals: BTreeMap<_, _> = sig.parameters.iter()
                .map(|p| (p.name.clone(), p.ty.clone())).collect();
            let ty = evaluate(
                expr,
                facts,
                model,
                &sig.receiver,
                sig.singleton,
                &mut locals,
            )
            .map(|t| t.inferred(format!("{id} at {location}")));
            let ivars: BTreeMap<_, _> = if ty.is_some() {
                locals.into_iter().filter(|(name, _)| name.starts_with('@'))
                    .map(|(name, ty)| (name, ty.inferred(format!("{id} at {location}")))).collect()
            } else { BTreeMap::new() };
            if let Some(ty) = ty
                && (ty != sig.return_type || ivars != sig.ivars)
            {
                changes.push((id.clone(), ty, ivars));
            }
        }
        if changes.is_empty() {
            break;
        }
        for (id, ty, ivars) in changes {
            let sig = model.methods.get_mut(&id).unwrap();
            sig.return_type = ty;
            sig.ivars = ivars;
        }
    }
}

pub(super) fn value(node: &Node<'_>, facts: &Facts, model: &TypeModel, receiver: &str,
    locals: &BTreeMap<String, Type>) -> Type {
    let mut ty = evaluate(&expression_ref(node), facts, model, receiver, false, &mut locals.clone())
        .unwrap_or_else(|| Type::new("untyped", Source::Inference, "unsupported view binding expression"));
    ty.evidence = if ty.provenance.iter().any(|p| p.source == Source::Observed) { Evidence::Observed }
        else { Evidence::Static };
    ty
}

fn evaluate(
    expr: &Expr,
    facts: &Facts,
    model: &TypeModel,
    receiver: &str,
    singleton: bool,
    locals: &mut BTreeMap<String, Type>,
) -> Option<Type> {
    match expr {
        Expr::Unknown => None,
        Expr::Literal(name) => {
            let mut ty = Type::new(*name, Source::Inference, "Ruby literal");
            ty.evidence = Evidence::ProvenBody;
            Some(ty)
        }
        Expr::Self_ => Some(Type::new(
            if singleton {
                format!("singleton({receiver})")
            } else {
                receiver.into()
            },
            Source::Inference,
            "self",
        )),
        Expr::Read(name) => Some(locals.get(name).cloned().unwrap_or_else(||
            Type::new("untyped", Source::Inference, format!("value unavailable: {name}")))),
        Expr::Write(name, value) => {
            let ty = evaluate(value, facts, model, receiver, singleton, locals)?;
            locals.insert(name.clone(), ty.clone());
            Some(ty)
        }
        Expr::Sequence(expressions) => {
            let mut last = Type::new("nil", Source::Inference, "empty body");
            let mut advisory = false;
            for expr in expressions {
                last = evaluate(expr, facts, model, receiver, singleton, locals)?;
                advisory |= last.evidence != Evidence::ProvenBody;
            }
            if advisory { last.evidence = Evidence::Static; }
            Some(last)
        }
        Expr::Branch(predicate, yes, no) => {
            evaluate(predicate, facts, model, receiver, singleton, locals)?;
            let mut yes_locals = locals.clone();
            let mut no_locals = locals.clone();
            let yes = evaluate(yes, facts, model, receiver, singleton, &mut yes_locals)?;
            let no = evaluate(no, facts, model, receiver, singleton, &mut no_locals)?;
            locals.clear();
            for (name, ty) in yes_locals {
                if let Some(other) = no_locals.remove(&name) {
                    locals.insert(name, union(vec![ty, other]));
                }
            }
            Some(union(vec![yes, no]))
        }
        Expr::Interpolation(parts) => {
            let mut values = Vec::new();
            for expr in parts {
                values.push(evaluate(expr, facts, model, receiver, singleton, locals)?);
                // Interpolation invokes app-overridable to_s conversions.
                locals.clear();
            }
            let mut ty = union(values);
            ty.name = "String".into();
            ty.provenance.push(Provenance { source: Source::Inference,
                detail: "Ruby interpolation on normal completion; no control-flow escape modeled".into() });
            Some(ty)
        }
        Expr::Array(elements) => {
            let elements = elements.iter().map(|expr|
                evaluate(expr, facts, model, receiver, singleton, locals)).collect::<Option<Vec<_>>>()?;
            Some(aggregate("Array", vec![elements]))
        }
        Expr::Hash(pairs) => {
            let mut keys = Vec::new();
            let mut values = Vec::new();
            for (key, value) in pairs {
                keys.push(evaluate(key, facts, model, receiver, singleton, locals)?);
                values.push(evaluate(value, facts, model, receiver, singleton, locals)?);
                // Hash insertion can invoke a key's hash/eql? methods.
                locals.clear();
            }
            Some(aggregate("Hash", vec![keys, values]))
        }
        Expr::Constant(name) => {
            // Autoload/const_missing can run arbitrary code.
            locals.clear();
            Some(Type::new("untyped", Source::Inference, format!("constant value unavailable: {name}")))
        }
        Expr::Call(target, name, arguments, safe_navigation) => {
            let mut receiver_provenance = Vec::new();
            let (class, single) = match target.as_deref() {
                None | Some(Expr::Self_) => (receiver.to_owned(), singleton),
                Some(Expr::Constant(class)) => {
                    locals.clear(); // autoload/const_missing, even before a zero-argument call
                    (class.clone(), true)
                }
                Some(target) => {
                    let ty = evaluate(target, facts, model, receiver, singleton, locals)?;
                    receiver_provenance = ty.provenance;
                    (ty.name, false)
                }
            };
            // A call may mutate the receiver's ivars, even when its return
            // type is known. Never carry an exit-ivar proof across it.
            if *arguments {
                // Argument calls can mutate locals through a captured binding.
                // We do not analyze their effects or retain stale local facts.
                locals.clear();
            } else {
                locals.retain(|name, _| !name.starts_with('@'));
            }
            let nullable_receiver = *safe_navigation && class.ends_with('?');
            let class = if nullable_receiver { class.trim_end_matches('?').to_owned() } else { class };
            let inherited = resolve(facts, &class, name, single)
                .and_then(|(owner, method)| model.get(&owner.name, &method.name, method.singleton));
            let mut ty = rails::lookup(facts, &class, name, single, Some(*arguments)).map(|s| s.return_type)
                .or_else(|| builtins::lookup(facts, &class, name, single))
                .or_else(|| model.get(&class, name, single).or(inherited)
                .map(|s| s.return_type.clone())
                )
                .unwrap_or_else(|| Type::new("untyped", Source::Inference,
                    format!("call contract unavailable: {}", key(&class, name, single))));
            for p in receiver_provenance {
                if !ty.provenance.contains(&p) { ty.provenance.push(p); }
            }
            if nullable_receiver { ty = union(vec![ty, Type::new("nil", Source::Inference, "safe navigation")]); }
            // Even a literal-returning callee can be replaced at runtime.
            // No call/lookup proof is supplied by this advisory walker.
            ty.evidence = Evidence::Static;
            Some(ty)
        }
    }
}

fn aggregate(name: &str, groups: Vec<Vec<Type>>) -> Type {
    let arguments: Vec<_> = groups.into_iter().map(union).collect();
    let mut ty = Type::new(format!("{name}[{}]", arguments.iter().map(|ty| ty.name.as_str()).collect::<Vec<_>>().join(", ")),
        Source::Inference, "Ruby container; element contracts advisory");
    for element in arguments {
        for source in element.provenance {
            if !ty.provenance.contains(&source) { ty.provenance.push(source); }
        }
    }
    ty
}

// Normalize the RBS names already used throughout the type model. Split only
// top-level union arms, never unions inside generic arguments or singleton().
fn union_members(name: &str, out: &mut BTreeSet<String>) {
    let name = name.trim();
    if let Some(inner) = name.strip_prefix('(').and_then(|s| s.strip_suffix(')')) {
        let mut depth = 0;
        let mut start = 0;
        for (index, byte) in inner.bytes().enumerate() {
            match byte {
                b'(' | b'[' => depth += 1,
                b')' | b']' => depth -= 1,
                b'|' if depth == 0 => {
                    union_members(&inner[start..index], out);
                    start = index + 1;
                }
                _ => {}
            }
        }
        union_members(&inner[start..], out);
    } else {
        out.insert(name.into());
    }
}

fn union(types: Vec<Type>) -> Type {
    let mut names = BTreeSet::new();
    for ty in &types { union_members(&ty.name, &mut names); }
    // Keep the existing nullable spelling. A nullable arm already covers nil
    // and its exact non-nullable counterpart; its inner type stays opaque.
    let nullable: Vec<_> = names.iter().filter_map(|n| n.strip_suffix('?').map(str::to_owned)).collect();
    if !nullable.is_empty() { names.remove("nil"); }
    for inner in nullable { names.remove(&inner); }
    let name = if names.is_empty() || names.contains("untyped") { "untyped".into() }
        else if names.len() == 1 { names.into_iter().next().unwrap() }
        else { format!("({})", names.into_iter().collect::<Vec<_>>().join(" | ")) };
    let mut ty = Type::new(name, Source::Inference, "advisory union; unknown members are not discarded");
    for source in types.into_iter().flat_map(|ty| ty.provenance) {
        if !ty.provenance.contains(&source) { ty.provenance.push(source); }
    }
    ty
}
