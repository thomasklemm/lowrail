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
            let self_type = sig.block_self.as_deref().map(|ty| format!(" [self: {ty}]")).unwrap_or_default();
            format!(" ?{{ (*untyped){self_type} -> untyped }}")
        } else {
            String::new()
        },
        sig.return_type.advisory_name()
    )
}

#[derive(Default)]
struct Declaration<'a> {
    kind: &'static str,
    generics: &'static str,
    superclass: Option<String>,
    includes: Vec<String>,
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
            // RBS core already declares Struct[E]. A Ruby subclass does not
            // constrain the element type; do not redeclare it without E.
            let parent = node.superclass.as_deref().map(|s|
                format!(" < ::{s}{}", if s == "Struct" { "[untyped]" } else { "" }))
                .unwrap_or_default();
            let _ = writeln!(out, "{indent}{kind} {name}{}{parent}", node.generics);
            for include in &node.includes { let _ = writeln!(out, "{indent}  include ::{include}"); }
            for sig in &node.methods {
                for (name, slot) in slots(sig) {
                    let _ = writeln!(out, "{indent}  # lowrail {name}: {}", serde_json::to_string(&slot).unwrap());
                }
                // Enum labels may produce methods such as "not yet?" or
                // "in-progress?", which Ruby permits via send.
                let base = sig.method.strip_suffix(['?', '!', '=']).unwrap_or(&sig.method);
                let ordinary = base.as_bytes().first().is_some_and(|b| b.is_ascii_alphabetic() || *b == b'_')
                    && base.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_');
                let method = if ordinary { sig.method.clone() } else { format!("`{}`", sig.method) };
                let _ = writeln!(
                    out,
                    "{indent}  def {}{}: {}",
                    if sig.singleton { "self." } else { "" },
                    method,
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
    // Empty app classes/helpers still need declarations. Their real booted
    // superclass supplies inherited Rails APIs; do not guess from naming.
    for module in &facts.modules {
        if observed::constant(&module.name)
            && module.const_source_location.as_deref().and_then(crate::facts::schema::split_location)
                .is_some_and(|(path, _)| facts.in_app(path))
        {
            root.at(&module.name).kind = if module.kind == "class" { "class" } else { "module" };
        }
    }
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
        if model.methods.values().any(|s| s.receiver == "Lowrail::RouteHelpers") {
            root.at(&controller.name).includes.push("Lowrail::RouteHelpers".into());
        }
    }
    let mut signatures = BTreeMap::new();
    for sig in model.methods.values() {
        if !observed::constant(&sig.receiver) {
            diagnostics.push(format!("RBS cannot declare receiver {} for {}", sig.receiver, sig.method));
            continue;
        }
        if sig.method.contains('`') || sig.method.chars().any(char::is_control) {
            diagnostics.push(format!("RBS cannot declare method {:?} on {}", sig.method, sig.receiver));
            continue;
        }
        root.at(&sig.receiver).methods.push(sig);
        signatures.insert(key(&sig.receiver, &sig.method, sig.singleton), ExportedSignature { rbs: sig.signature(), slots: slots(sig) });
    }
    loop {
        let mut parents = Vec::new();
        for module in &facts.modules {
            if let Some(node) = root.existing(&module.name) {
                node.kind = if module.kind == "class" { "class" } else { "module" };
                if module.kind == "class" && let Some(parent) = &module.superclass
                    && observed::constant(parent) && !matches!(parent.as_str(), "Object" | "BasicObject")
                {
                    node.superclass = Some(parent.clone());
                    if parent != "Struct" { parents.push(parent.clone()); }
                }
            }
        }
        let missing: Vec<_> = parents.into_iter().filter(|p| root.existing(p).is_none()).collect();
        if missing.is_empty() { break; }
        for parent in missing { root.at(&parent).kind = "class"; }
    }
    let coverage = coverage(model);
    let mut app = format!("# Generated by lowrail types; advisory, not runtime guards.\n# lowrail coverage: {}\n", serde_json::to_string(&coverage).unwrap());
    root.render(&mut app, "");
    // Minimal declarations for standalone validation, not a replacement for
    // Rails signatures. Keep this separate when using a Rails RBS collection.
    let mut support = String::from("# Bounded real-Rails API support; omit when loading full Rails signatures.\n");
    // Samples and catalog contracts can introduce external classes. Emit
    // name-only stubs, not invented signatures, for those namespaced classes.
    let mut external = Declaration::default();
    for (name, generics, superclass) in [
        ("BigDecimal", "", Some("Numeric")),
        ("Date", "", None),
        ("DateTime", "", Some("Date")),
        ("Tempfile", "", None),
        ("ActiveSupport::TimeWithZone", "", None),
        ("ActiveSupport::SafeBuffer", "", Some("String")),
        ("ActiveRecord::Relation", "[Elem]", None),
        ("ActiveRecord::Associations::CollectionProxy", "[Elem]", Some("ActiveRecord::Relation[Elem]")),
        ("ActiveRecord::QueryMethods::WhereChain", "", None),
    ] {
        let node = external.at(name);
        node.kind = "class";
        node.generics = generics;
        node.superclass = superclass.map(String::from);
    }
    let library = rails::support(facts);
    for sig in &library {
        let receiver = sig.receiver.strip_suffix("[Elem]").unwrap_or(&sig.receiver);
        external.at(receiver).methods.push(sig);
        external.at(receiver).kind = "class";
    }
    for sig in model.methods.values() {
        for ty in std::iter::once(&sig.return_type).chain(sig.parameters.iter().map(|p| &p.ty)) {
            if !ty.provenance.iter().any(|p| matches!(p.source, Source::Observed | Source::SorbetSig | Source::RailsApi)) { continue; }
            for name in ty.name.split(|c: char| !c.is_ascii_alphanumeric() && c != '_' && c != ':') {
                let name = name.trim_start_matches("::");
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
