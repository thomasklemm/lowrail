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
    Call(Option<Box<Expr>>, String),
    Sequence(Vec<Expr>),
    Read(String),
    Write(String, Box<Expr>),
}

fn expression(node: Node<'_>) -> Expr {
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
    } else if let Some(n) = node.as_call_node() {
        if n.block().is_none() && n.arguments().is_none() && !n.is_safe_navigation() {
            Expr::Call(
                n.receiver().map(|r| Box::new(expression(r))),
                String::from_utf8_lossy(n.name().as_slice()).into(),
            )
        } else {
            Expr::Unknown
        }
    } else {
        // Never infer just the tail of a body with unsupported control flow.
        Expr::Unknown
    }
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
        let line = self.source[..n.location().start_offset()]
            .iter()
            .filter(|b| **b == b'\n')
            .count() as u32
            + 1;
        self.defs.insert(
            (line, String::from_utf8_lossy(n.name().as_slice()).into()),
            n.body().map(expression).unwrap_or(Expr::Literal("nil")),
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

    fn load(path: &str, diagnostics: &mut Vec<String>) -> Self {
        let mut index = Index::default();
        match std::fs::read(path) {
            Ok(source) => {
                let parsed = ruby_prism::parse(&source);
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

pub(super) fn analyze(facts: &Facts, model: &mut TypeModel) {
    let classifier = facts::Classifier::new(facts);
    let mut indexes = BTreeMap::new();
    let mut bodies = BTreeMap::new();
    for module in &facts.modules {
        if let Some((path, _)) = module
            .const_source_location
            .as_deref()
            .and_then(split_location)
            && classifier.in_app(path)
        {
            indexes
                .entry(path.to_owned())
                .or_insert_with(|| Index::load(path, &mut model.diagnostics));
        }
    }
    for module in &facts.modules {
        for method in &module.methods {
            let Some((path, line)) = method.source_location.as_deref().and_then(split_location)
            else {
                continue;
            };
            if !classifier.in_app(path) {
                continue;
            }
            let index = indexes
                .entry(path.to_owned())
                .or_insert_with(|| Index::load(path, &mut model.diagnostics));
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
    // Boot parameters and ownership override catalog guesses, including custom
    // readers. Resolve ancestor methods for model accessors as well.
    let ids: Vec<_> = model.methods.keys().cloned().collect();
    for id in ids {
        let sig = &model.methods[&id];
        if let Some((owner, method)) = resolve(facts, &sig.receiver, &sig.method, sig.singleton) {
            let own_key = key(&owner.name, &method.name, method.singleton);
            let body = bodies.get(&own_key).cloned();
            let sig = model.methods.get_mut(&id).unwrap();
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
            if let Some(body) = body {
                sig.return_type =
                    Type::new("untyped", Source::BootFact, format!("custom body of {id}"));
                bodies.insert(id, body);
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
            let ty = evaluate(
                expr,
                model,
                &sig.receiver,
                sig.singleton,
                &mut BTreeMap::new(),
            )
            .map(|t| t.inferred(format!("{id} at {location}")));
            if let Some(ty) = ty
                && ty.name != sig.return_type.name
            {
                changes.push((id.clone(), ty));
            }
        }
        if changes.is_empty() {
            break;
        }
        for (id, ty) in changes {
            model.methods.get_mut(&id).unwrap().return_type = ty;
        }
    }
}

fn evaluate(
    expr: &Expr,
    model: &TypeModel,
    receiver: &str,
    singleton: bool,
    locals: &mut BTreeMap<String, Type>,
) -> Option<Type> {
    match expr {
        Expr::Unknown => None,
        Expr::Literal(name) => Some(Type::new(*name, Source::Inference, "Ruby literal")),
        Expr::Self_ => Some(Type::new(
            if singleton {
                format!("singleton({receiver})")
            } else {
                receiver.into()
            },
            Source::Inference,
            "self",
        )),
        Expr::Read(name) => locals.get(name).cloned(),
        Expr::Write(name, value) => {
            let ty = evaluate(value, model, receiver, singleton, locals)?;
            locals.insert(name.clone(), ty.clone());
            Some(ty)
        }
        Expr::Sequence(expressions) => {
            let mut last = Type::new("nil", Source::Inference, "empty body");
            for expr in expressions {
                last = evaluate(expr, model, receiver, singleton, locals)?;
            }
            Some(last)
        }
        Expr::Constant(_) => None,
        Expr::Call(target, name) => {
            let (class, single) = match target.as_deref() {
                None | Some(Expr::Self_) => (receiver.to_owned(), singleton),
                Some(Expr::Constant(class)) => (class.clone(), true),
                Some(target) => (
                    evaluate(target, model, receiver, singleton, locals)?.name,
                    false,
                ),
            };
            let ty = model.get(&class, name, single)?.return_type.clone();
            (ty.name != "untyped").then_some(ty)
        }
    }
}
