//! Boot-first advisory types. These are not guards and never authorize lowering.
mod infer;
mod observed;
mod position;
mod rails;
mod rbs;
mod sorbet;
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
    RailsApi,
    #[serde(rename = "sorbet sig")]
    SorbetSig,
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
    pub evidence: Evidence,
    /// Raw class histogram, never a confidence score or a proof.
    pub samples: BTreeMap<String, u64>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Evidence {
    /// No value check within this analyzed body. The consumer must still
    /// certify effective method lookup/source and the surrounding execution.
    ProvenBody,
    Static,
    Observed,
}

impl Type {
    fn new(name: impl Into<String>, source: Source, detail: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            provenance: vec![Provenance {
                source,
                detail: detail.into(),
            }],
            evidence: Evidence::Static,
            samples: BTreeMap::new(),
        }
    }

    pub fn proven_type(&self) -> Option<&str> {
        (self.evidence == Evidence::ProvenBody && self.name != "untyped")
            .then_some(self.name.as_str())
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
    /// Per-method exit facts, not controller-to-view flow guarantees.
    pub ivars: BTreeMap<String, Type>,
    pub observation: Option<crate::observe::MethodTypes>,
    /// Action/callback roles do not imply a particular Ruby return value.
    pub roles: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub block_self: Option<String>,
}

impl Signature {
    pub fn signature(&self) -> String {
        rbs::signature(self)
    }

    /// Stable build-input query: `return`, `arg:name`, or `ivar:@name`.
    pub fn fact(&self, slot: &str) -> Option<&Type> {
        if slot == "return" {
            Some(&self.return_type)
        } else if let Some(name) = slot.strip_prefix("arg:") {
            self.parameters.iter().find(|p| p.name == name).map(|p| &p.ty)
        } else {
            self.ivars.get(slot.strip_prefix("ivar:")?)
        }
    }
}

#[derive(Debug, Serialize)]
pub struct Conflict {
    pub method: String,
    pub slot: String,
    pub static_type: String,
    pub observed_class: String,
    pub count: u64,
}

#[derive(Debug, Default, Serialize)]
pub struct TypeModel {
    pub methods: BTreeMap<String, Signature>,
    pub diagnostics: Vec<String>,
    pub conflicts: Vec<Conflict>,
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
    for (index, &ancestor) in names.iter().enumerate() {
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
        let module = if let Some(m) = facts.modules.iter().find(|m| m.name == ancestor) {
            Some(m)
        } else if !singleton && ancestor.starts_with('#')
            && facts.models.iter().any(|m| m.name == receiver)
        {
            // Anonymous owner labels have their object IDs erased. An indexed
            // model ancestor is exact; a holder is usable only at a unique
            // position. Never skip an ambiguous module to a later definition.
            let indexed = format!("{receiver}.ancestors[{index}]");
            let prefix = format!("{receiver}.");
            let mut candidates = facts.modules.iter().filter(|m| m.synthetic && (
                m.name == indexed || (m.name.starts_with(&prefix)
                    && !m.name.contains(".ancestors[")
                    && names.iter().filter(|&&n| n == ancestor).count() == 1
                    && m.methods.iter().any(|method| method.owner == ancestor))));
            let first = candidates.next()?;
            if candidates.next().is_some() { return None; }
            Some(first)
        } else {
            None
        };
        if let Some(m) = module
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
    pub fn load(app: &Path, facts: &Facts) -> Result<Self, String> {
        let mut model = Self::from_facts(facts)?;
        if let Some(bytes) = observed::read(app)? {
            model.merge_observed(facts, &bytes)?;
        }
        Ok(model)
    }

    pub fn from_facts(facts: &Facts) -> Result<Self, String> {
        let parser = crate::parser::Parser::for_runtime(&facts.ruby_description)?;
        let mut out = Self::default();
        for model in &facts.models {
            for column in &model.columns {
                let ty = scalar(column.type_.as_deref());
                let ty = Type::new(
                    // NOT NULL constrains stored rows, not unsaved objects.
                    nullable(ty, true),
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
                let target = if assoc.options["polymorphic"] == true {
                    "untyped"
                } else {
                    assoc.class_name.as_deref().unwrap_or("untyped")
                };
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
            // `where()` returns WhereChain and `unscoped {}` returns the
            // block's value; neither has an unconditional relation return.
            for name in ["all", "order", "limit", "joins", "includes", "none"] {
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
                for suffix in ["path", "url"] {
                    out.insert(
                        "Lowrail::RouteHelpers",
                        &format!("{name}_{suffix}"),
                        false,
                        Type::new("String", Source::BootFact, format!("route {name}: {}", route.path)),
                    );
                }
            }
        }
        rails::seed(facts, &mut out);
        infer::analyze(facts, &mut out, &parser);
        Ok(out)
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
                ivars: BTreeMap::new(),
                observation: None,
                roles: vec![],
                block_self: None,
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

    pub fn fact(&self, target: &str, slot: &str) -> Option<&Type> {
        self.lookup(target)?.fact(slot)
    }

    pub fn typed_facts(&self) -> serde_json::Value {
        serde_json::json!({"format":1, "methods":self.methods,
            "coverage":rbs::coverage(self), "conflicts":self.conflicts, "diagnostics":self.diagnostics})
    }

    pub fn type_at_position(&self, facts: &Facts, path: &str, line: u64, column: u64) -> Result<serde_json::Value, String> {
        position::query(self, facts, path, line, column)
    }

    pub fn export_rbs(&self, facts: &Facts) -> rbs::Export<'_> {
        rbs::export(self, facts)
    }

    pub fn write_rbs(&self, facts: &Facts, out: &Path) -> Result<(), String> {
        rbs::write(self, facts, out)
    }
}

fn scalar(ty: Option<&str>) -> &'static str {
    match ty {
        Some("string" | "text" | "binary" | "uuid" | "enum") => "String",
        Some("integer" | "bigint") => "Integer",
        Some("float") => "Float",
        Some("decimal") => "BigDecimal",
        Some("boolean") => "bool",
        Some("date") => "Date",
        // The dump does not pin time-zone-aware attribute configuration.
        Some("datetime" | "timestamp" | "time") => "(Time | ActiveSupport::TimeWithZone)",
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
    let usage = "usage: lowrail types --rbs APP (standalone RBS to stdout) | types APP [--facts PATH] [--rbs OUT_DIR] (JSON and optional RBS files)";
    if let [flag, app] = args && flag == "--rbs" {
        let facts = facts::load(Path::new(app).join(".lowrail/facts.json"))?;
        let model = TypeModel::load(Path::new(app), &facts)?;
        let export = model.export_rbs(&facts);
        print!("{}{}", export.files["lowrail_support.rbs"], export.files["app.rbs"]);
        for diagnostic in export.diagnostics { eprintln!("RBS: {diagnostic}"); }
        return Ok(());
    }
    let (app, rest) = args.split_first().ok_or(usage)?;
    let mut facts_path = Path::new(app).join(".lowrail/facts.json");
    let mut out = None;
    let mut options = rest.chunks_exact(2);
    for pair in &mut options {
        match pair[0].as_str() {
            "--facts" => facts_path = pair[1].clone().into(),
            "--rbs" => out = Some(Path::new(&pair[1])),
            _ => return Err(usage.into()),
        }
    }
    if !options.remainder().is_empty() { return Err(usage.into()); }
    let facts = facts::load(facts_path)?;
    let model = TypeModel::load(Path::new(app), &facts)?;
    if let Some(out) = out {
        model.write_rbs(&facts, out)?;
    }
    println!(
        "{}",
        serde_json::to_string_pretty(&model.typed_facts()).map_err(|e| e.to_string())?
    );
    Ok(())
}
