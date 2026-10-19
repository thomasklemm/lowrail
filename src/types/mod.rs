//! Boot-first advisory types. These are not guards and never authorize lowering.
mod infer;
mod rbs;
#[cfg(test)]
mod tests;

use crate::facts::schema::{Method, Module};
use crate::facts::{self, Facts};
use serde::Serialize;
use std::collections::BTreeMap;
use std::path::Path;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Source {
    BootFact,
    Schema,
    Inference,
    Observed,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Provenance {
    pub source: Source,
    pub detail: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Type {
    pub name: String,
    pub provenance: Vec<Provenance>,
}

impl Type {
    fn new(name: impl Into<String>, source: Source, detail: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            provenance: vec![Provenance {
                source,
                detail: detail.into(),
            }],
        }
    }

    fn inferred(mut self, detail: String) -> Self {
        let p = Provenance {
            source: Source::Inference,
            detail,
        };
        if !self.provenance.contains(&p) {
            self.provenance.push(p);
        }
        self
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct Parameter {
    pub kind: String,
    pub name: String,
    pub ty: Type,
}

#[derive(Debug, Clone, Serialize)]
pub struct Signature {
    pub receiver: String,
    pub method: String,
    pub singleton: bool,
    pub parameters: Vec<Parameter>,
    pub return_type: Type,
    /// Action/callback roles do not imply a particular Ruby return value.
    pub roles: Vec<String>,
}

impl Signature {
    pub fn signature(&self) -> String {
        rbs::signature(self)
    }
}

#[derive(Debug, Default, Serialize)]
pub struct TypeModel {
    pub methods: BTreeMap<String, Signature>,
    pub diagnostics: Vec<String>,
}

pub fn key(receiver: &str, method: &str, singleton: bool) -> String {
    format!("{receiver}{}{method}", if singleton { "." } else { "#" })
}

/// Resolve using the booted ancestor order, not source-level inheritance guesses.
pub fn resolve<'a>(
    facts: &'a Facts,
    receiver: &str,
    name: &str,
    singleton: bool,
) -> Option<(&'a Module, &'a Method)> {
    let module = facts.modules.iter().find(|m| m.name == receiver)?;
    let ancestors = if singleton {
        &module.singleton_ancestors
    } else {
        &module.ancestors
    };
    let names: Vec<&str> = if ancestors.is_empty() {
        vec![receiver]
    } else {
        ancestors.iter().map(String::as_str).collect()
    };
    for ancestor in names {
        let (ancestor, single) = if singleton {
            match ancestor
                .strip_prefix("#<Class:")
                .and_then(|n| n.strip_suffix('>'))
            {
                Some(n) => (n, true),
                None if ancestor == receiver => (ancestor, true),
                None => (ancestor, false),
            }
        } else {
            (ancestor, false)
        };
        if let Some(m) = facts.modules.iter().find(|m| m.name == ancestor)
            && let Some(method) = m
                .methods
                .iter()
                .find(|m| m.name == name && m.singleton == single)
        {
            return Some((m, method));
        }
    }
    None
}

impl TypeModel {
    pub fn from_facts(facts: &Facts) -> Self {
        let mut out = Self::default();
        for model in &facts.models {
            for column in &model.columns {
                let ty = scalar(column.type_.as_deref());
                let ty = Type::new(
                    nullable(ty, column.null),
                    Source::Schema,
                    format!(
                        "{}.{}: type={:?}, null={}",
                        model.table, column.name, column.type_, column.null
                    ),
                );
                out.attribute(&model.name, &column.name, ty);
            }
            for attr in &model.attributes {
                out.attribute(
                    &model.name,
                    &attr.name,
                    Type::new(
                        nullable(scalar(attr.type_.as_str()), true),
                        Source::BootFact,
                        format!("{}.attribute {}", model.name, attr.name),
                    ),
                );
            }
            for (alias, original) in &model.attribute_aliases {
                if let Some(sig) = out.get(&model.name, original, false) {
                    out.attribute(&model.name, alias, sig.return_type.clone());
                }
            }
            for assoc in &model.associations {
                let target = assoc.class_name.as_deref().unwrap_or("untyped");
                // Validation of presence is not a guarantee on an unsaved record.
                let ty = match assoc.macro_.as_str() {
                    "has_many" | "has_and_belongs_to_many" => {
                        format!("ActiveRecord::Associations::CollectionProxy[{target}]")
                    }
                    "belongs_to" | "has_one" => nullable(target, true),
                    _ => "untyped".into(),
                };
                out.insert(
                    &model.name,
                    &assoc.name,
                    false,
                    Type::new(
                        ty,
                        Source::BootFact,
                        format!("{}.{} {}", model.name, assoc.macro_, assoc.name),
                    ),
                );
            }
            for name in [
                "all", "where", "order", "limit", "joins", "includes", "none", "unscoped",
            ] {
                out.insert(
                    &model.name,
                    name,
                    true,
                    Type::new(
                        format!("ActiveRecord::Relation[{}]", model.name),
                        Source::BootFact,
                        format!("ActiveRecord model {}", model.name),
                    ),
                );
            }
        }
        for controller in &facts.controllers {
            for action in &controller.actions {
                out.role(&controller.name, action, "action");
            }
            for callback in &controller.callbacks {
                if callback.kind == "before" && callback.filter_type == "method" {
                    out.role(&controller.name, &callback.filter, "before_action");
                }
            }
        }
        for route in &facts.routes {
            if let Some(name) = &route.name {
                out.insert(
                    "Lowrail::RouteHelpers",
                    &format!("{name}_path"),
                    false,
                    Type::new(
                        "String",
                        Source::BootFact,
                        format!("route {name}: {}", route.path),
                    ),
                );
            }
        }
        infer::analyze(facts, &mut out);
        out
    }

    fn role(&mut self, receiver: &str, method: &str, role: &str) {
        let sig = self.insert(
            receiver,
            method,
            false,
            Type::new(
                "untyped",
                Source::BootFact,
                format!("{receiver} {role} {method}"),
            ),
        );
        sig.roles.push(role.into());
    }

    fn attribute(&mut self, receiver: &str, name: &str, ty: Type) {
        self.insert(receiver, name, false, ty.clone());
        let writer = self.insert(receiver, &format!("{name}="), false, ty.clone());
        // AR accepts values for casting; the storage type is not the input type.
        writer.parameters = vec![Parameter {
            kind: "req".into(),
            name: "value".into(),
            ty: Type::new("untyped", Source::BootFact, "ActiveRecord type casting"),
        }];
        // Calling the writer with send returns its input, not the cast attribute.
        writer.return_type = Type::new(
            "untyped",
            Source::BootFact,
            "attribute writer returns input",
        );
    }

    fn insert(
        &mut self,
        receiver: &str,
        method: &str,
        singleton: bool,
        ty: Type,
    ) -> &mut Signature {
        self.methods
            .entry(key(receiver, method, singleton))
            .or_insert(Signature {
                receiver: receiver.into(),
                method: method.into(),
                singleton,
                parameters: vec![Parameter {
                    kind: "rest".into(),
                    name: "args".into(),
                    ty: Type::new("untyped", Source::BootFact, "parameters not recorded"),
                }],
                return_type: ty,
                roles: vec![],
            })
    }

    pub fn get(&self, receiver: &str, method: &str, singleton: bool) -> Option<&Signature> {
        self.methods.get(&key(receiver, method, singleton))
    }

    pub fn lookup(&self, query: &str) -> Option<&Signature> {
        self.methods
            .get(query)
            .or_else(|| self.get("Lowrail::RouteHelpers", query, false))
    }

    pub fn write_rbs(&self, facts: &Facts, out: &Path) -> Result<(), String> {
        rbs::write(self, facts, out)
    }
}

fn scalar(ty: Option<&str>) -> &'static str {
    match ty {
        Some("string" | "text" | "binary" | "enum") => "String",
        Some("integer" | "bigint") => "Integer",
        Some("float") => "Float",
        Some("decimal") => "BigDecimal",
        Some("boolean") => "bool",
        Some("date") => "Date",
        Some("datetime" | "timestamp" | "time") => "Time",
        Some("json" | "jsonb") => "untyped",
        _ => "untyped",
    }
}

fn nullable(ty: &str, null: bool) -> String {
    if null && ty != "untyped" {
        format!("{ty}?")
    } else {
        ty.into()
    }
}

pub fn cli(args: &[String]) -> Result<(), String> {
    let usage = "usage: lowrail types APP [--rbs OUT_DIR]";
    let (app, rest) = args.split_first().ok_or(usage)?;
    if !(rest.is_empty() || rest.len() == 2 && rest[0] == "--rbs") {
        return Err(usage.into());
    }
    let facts = facts::load(Path::new(app).join(".lowrail/facts.json"))?;
    let model = TypeModel::from_facts(&facts);
    if rest.len() == 2 {
        model.write_rbs(&facts, Path::new(&rest[1]))?;
    }
    println!(
        "{}",
        serde_json::to_string_pretty(&model).map_err(|e| e.to_string())?
    );
    Ok(())
}
