use super::*;
use std::fmt::Write as _;

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Status { Proven, Static, Observed, Unknown }

#[derive(Default, Serialize)]
pub struct Coverage {
    pub proven: usize,
    pub r#static: usize,
    pub observed: usize,
    pub unknown: usize,
}

#[derive(Serialize)]
pub struct Slot<'a> {
    pub status: Status,
    pub scope: Option<&'static str>,
    pub sample_count: u64,
    pub fact: &'a Type,
}

#[derive(Serialize)]
pub struct ExportedSignature<'a> {
    pub rbs: String,
    pub slots: BTreeMap<String, Slot<'a>>,
}

#[derive(Serialize)]
pub struct Export<'a> {
    pub format: u32,
    pub coverage: Coverage,
    pub files: BTreeMap<String, String>,
    pub signatures: BTreeMap<String, ExportedSignature<'a>>,
    pub diagnostics: Vec<String>,
    pub conflicts: &'a [Conflict],
}

fn slots(sig: &Signature) -> BTreeMap<String, Slot<'_>> {
    std::iter::once(("return".into(), &sig.return_type))
        .chain(sig.parameters.iter().map(|p| (format!("arg:{}", p.name), &p.ty)))
        .map(|(name, fact)| {
            let status = if fact.name == "untyped" { Status::Unknown } else {
                match fact.evidence {
                    Evidence::ProvenBody => Status::Proven,
                    Evidence::Static => Status::Static,
                    Evidence::Observed => Status::Observed,
                }
            };
            let scope = matches!(status, Status::Proven).then_some("body-local; effective method/source and execution context still require certification");
            (name, Slot { status, scope, sample_count: fact.samples.values().sum(), fact })
        }).collect()
}

pub(super) fn coverage(model: &TypeModel) -> Coverage {
    let mut counts = Coverage::default();
    for sig in model.methods.values() {
        for slot in slots(sig).into_values() {
            match slot.status {
                Status::Proven => counts.proven += 1,
                Status::Static => counts.r#static += 1,
                Status::Observed => counts.observed += 1,
                Status::Unknown => counts.unknown += 1,
            }
        }
    }
    counts
}

pub(super) fn signature(sig: &Signature) -> String {
    let mut params = Vec::new();
    let mut block = false;
    for p in &sig.parameters {
        let t = &p.ty.name;
        params.push(match p.kind.as_str() {
            "req" => t.clone(),
            "opt" => format!("?{t}"),
            "rest" => format!("*{t}"),
            "keyreq" => format!("{}: {t}", p.name),
            "key" => format!("?{}: {t}", p.name),
            "keyrest" => format!("**{t}"),
            "nokey" => "**nil".into(),
            "block" => {
                block = true;
                continue;
            }
            _ => continue,
        });
    }
    format!(
        "({}){} -> {}",
        params.join(", "),
        if block {
            " ?{ (*untyped) -> untyped }"
        } else {
            ""
        },
        sig.return_type.name
    )
}

#[derive(Default)]
struct Declaration<'a> {
    kind: &'static str,
    children: BTreeMap<String, Declaration<'a>>,
    methods: Vec<&'a Signature>,
}

impl<'a> Declaration<'a> {
    fn at(&mut self, name: &str) -> &mut Self {
        name.split("::").fold(self, |node, part| {
            node.children.entry(part.into()).or_default()
        })
    }

    fn existing(&mut self, name: &str) -> Option<&mut Self> {
        name.split("::").try_fold(self, |node, part| node.children.get_mut(part))
    }

    fn render(&self, out: &mut String, indent: &str) {
        for (name, node) in &self.children {
            let kind = if node.kind.is_empty() {
                "module"
            } else {
                node.kind
            };
            let _ = writeln!(out, "{indent}{kind} {name}");
            for sig in &node.methods {
                for (name, slot) in slots(sig) {
                    let _ = writeln!(out, "{indent}  # lowrail {name}: {}", serde_json::to_string(&slot).unwrap());
                }
                let _ = writeln!(
                    out,
                    "{indent}  def {}{}: {}",
                    if sig.singleton { "self." } else { "" },
                    sig.method,
                    sig.signature()
                );
            }
            node.render(out, &format!("{indent}  "));
            let _ = writeln!(out, "{indent}end");
        }
    }
}

pub(super) fn export<'a>(model: &'a TypeModel, facts: &Facts) -> Export<'a> {
    let mut root = Declaration::default();
    let mut diagnostics = model.diagnostics.clone();
    for record in facts.models.iter().filter(|m| observed::constant(&m.name)) {
        root.at(&record.name).kind = "class";
        for assoc in &record.associations {
            if let Some(target) = &assoc.class_name && observed::constant(target) {
                root.at(target).kind = "class";
            }
        }
    }
    for controller in facts.controllers.iter().filter(|c| observed::constant(&c.name)) {
        root.at(&controller.name).kind = "class";
    }
    let mut signatures = BTreeMap::new();
    for sig in model.methods.values() {
        if !observed::constant(&sig.receiver) {
            diagnostics.push(format!("RBS cannot declare receiver {} for {}", sig.receiver, sig.method));
            continue;
        }
        // RBS can merge these with a user's signatures without declaring a
        // potentially different superclass. Facts still drive all members.
        root.at(&sig.receiver).methods.push(sig);
        signatures.insert(key(&sig.receiver, &sig.method, sig.singleton), ExportedSignature { rbs: sig.signature(), slots: slots(sig) });
    }
    for module in &facts.modules {
        // A class may be only a namespace here, not a method receiver.
        if let Some(node) = root.existing(&module.name) {
            node.kind = if module.kind == "class" {
                "class"
            } else {
                "module"
            };
        }
    }
    let coverage = coverage(model);
    let mut app = format!("# Generated by lowrail types; advisory, not runtime guards.\n# lowrail coverage: {}\n", serde_json::to_string(&coverage).unwrap());
    root.render(&mut app, "");
    // Minimal declarations for standalone validation, not a replacement for
    // Rails signatures. Keep this separate when using a Rails RBS collection.
    let mut support = String::from("# Omit when loading full Rails signatures.\nclass BigDecimal < Numeric\nend\nclass Date\nend\nclass Tempfile\nend\nmodule ActiveSupport\n  class TimeWithZone\n  end\nend\nmodule ActiveRecord\n  class Relation[Elem]\n  end\n  module Associations\n    class CollectionProxy[Elem] < Relation[Elem]\n    end\n  end\nend\n");
    // Samples can introduce framework classes not used by the static catalog
    // (e.g. strong parameters or safe strings). Emit name-only stubs, not
    // invented signatures, for those namespaced external classes.
    let mut external = Declaration::default();
    for sig in model.methods.values() {
        for ty in std::iter::once(&sig.return_type).chain(sig.parameters.iter().map(|p| &p.ty)) {
            if !ty.provenance.iter().any(|p| p.source == Source::Observed) { continue; }
            for name in ty.name.split(|c: char| !c.is_ascii_alphanumeric() && c != '_' && c != ':') {
                if !name.contains("::") || !observed::constant(name)
                    || matches!(name, "Thread::Queue" | "ActiveSupport::TimeWithZone" | "ActiveRecord::Relation" | "ActiveRecord::Associations::CollectionProxy")
                    || root.existing(name).is_some()
                { continue; }
                external.at(name).kind = "class";
            }
        }
    }
    for module in &facts.modules {
        if let Some(node) = external.existing(&module.name) {
            node.kind = if module.kind == "class" { "class" } else { "module" };
        }
    }
    external.render(&mut support, "");
    Export { format: 1, coverage, files: BTreeMap::from([("app.rbs".into(), app), ("lowrail_support.rbs".into(), support)]), signatures, diagnostics, conflicts: &model.conflicts }
}

pub(super) fn write(model: &TypeModel, facts: &Facts, out: &Path) -> Result<(), String> {
    let export = export(model, facts);
    std::fs::create_dir_all(out).map_err(|e| e.to_string())?;
    for (name, content) in export.files {
        std::fs::write(out.join(name), content).map_err(|e| e.to_string())?;
    }
    for diagnostic in export.diagnostics { eprintln!("RBS: {diagnostic}"); }
    Ok(())
}
