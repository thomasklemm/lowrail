//! Read-only provenance, shared by CLI, doctor and MCP. No Ruby boot or guard
//! evaluation: certification, emitted artifacts and runtime observations are
//! different evidence and must never be presented as proof of one another.
use crate::facts;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[derive(Debug, Serialize, Deserialize)]
pub struct Report {
    pub format: u32,
    pub app: String,
    pub artifact_dir: String,
    pub manifest_available: bool,
    pub ledger_available: bool,
    pub selected_passes: Option<Vec<String>>,
    pub certification_jit: Option<String>,
    pub rails_env: Option<String>,
    pub tier: Option<String>,
    pub facts: Option<FactSummary>,
    pub delivery_refusals: Vec<Reason>,
    pub stats: Option<Statistics>,
    pub units: Vec<Unit>,
    pub sites: Vec<Site>,
    pub notes: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FactSummary {
    pub path: String,
    pub ruby_description: String,
    pub rails_version: Option<String>,
    pub yjit: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Reason { pub code: String, pub detail: String }

#[derive(Debug, Serialize, Deserialize)]
pub struct Statistics {
    pub source: String,
    /// current_manifest, stale_manifest, or unbound_snapshot. Even a current
    /// verify is historical, not proof that today's sources/guards still hold.
    pub binding: String,
    pub unit_hits: BTreeMap<String, u64>,
    pub unit_fallbacks: BTreeMap<String, u64>,
    pub unit_refusals: BTreeMap<String, Vec<String>>,
    pub jit_modes: Vec<Value>,
    pub refusals: Vec<Reason>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Counts { pub hits: u64, pub fallbacks: u64 }

#[derive(Debug, Serialize, Deserialize)]
pub struct Guard { pub phase: String, pub requirement: String }

#[derive(Debug, Serialize, Deserialize)]
pub struct Unit {
    pub id: u64,
    pub pass: String,
    pub target: String,
    pub kind: String,
    pub certification_jit: Option<String>,
    pub certified_facts: Vec<Value>,
    pub certificates: BTreeMap<String, Value>,
    pub guards: Vec<Guard>,
    /// Current runtime policy, not a rewriting of the build decision or
    /// historical counters. Applies even when no stats were collected.
    pub activation_refusal: Option<Reason>,
    pub counts: Option<Counts>,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Status { Lowered, Refused, Ledgered, LeftOriginal }

#[derive(Debug, Serialize, Deserialize)]
pub struct Location { pub path: String, pub line: u64, pub origin: String }

#[derive(Debug, Serialize, Deserialize)]
pub struct Site {
    pub target: String,
    pub line: u64,
    pub location: Option<Location>,
    pub site: String,
    pub pass: Option<String>,
    pub status: Status,
    pub reason: Reason,
    pub unit_ids: Vec<u64>,
    /// Preserve copies, survey metadata, and the original build decision even
    /// when the compiler did not emit a corresponding unit.
    pub ledger: Option<Value>,
}

fn text(v: &Value) -> Option<String> { v.as_str().map(str::to_owned) }

pub fn read(app: &Path, dir: Option<&Path>, stats: Option<&Path>, id: Option<u64>, location: Option<&str>, pass: Option<&str>) -> Result<Report, String> {
    let dir = dir.map_or_else(|| app.join(".lowrail"), |p| app.join(p));
    let raw = facts::read_json(&dir.join("manifest.json"))?;
    let mut manifest = raw.clone().unwrap_or(Value::Null);
    if raw.is_some() {
        if !matches!(manifest["format"].as_u64(), Some(1 | 2)) || !manifest["units"].is_array() {
            return Err("invalid or unsupported manifest; rebuild before explaining it".into());
        }
        if manifest["format"] == 2 { facts::resolve_paths(&mut manifest, app)?; }
    }
    let ledger = facts::read_json(&dir.join("ledger.json"))?;
    let rows = ledger.as_ref().map(|v| v.as_array().ok_or("ledger must be an array")).transpose()?;
    let facts_path = if dir.join("facts.json").exists() { dir.join("facts.json") } else { app.join(".lowrail/facts.json") };
    let boot = if facts_path.exists() { Some(facts::load(&facts_path)?) } else { None };
    let stats_path = stats.map_or_else(|| dir.join("verify/last.json"), |p| app.join(p));
    let statistics = read_stats(&stats_path, raw.as_ref())?;
    let mut units = Vec::new();
    for u in manifest["units"].as_array().into_iter().flatten() {
        let id = u["id"].as_u64().ok_or("unit missing numeric id")?;
        let name = u["pass"].as_str().ok_or("unit missing pass")?;
        let counts = statistics.as_ref().filter(|s| s.binding == "current_manifest").map(|s| Counts {
            hits: s.unit_hits.get(&id.to_string()).copied().unwrap_or(0),
            fallbacks: s.unit_fallbacks.get(&id.to_string()).copied().unwrap_or(0),
        });
        units.push(Unit { id, pass: name.into(), target: text(&u["target"]).or_else(|| text(&u["file"])).unwrap_or_default(),
            kind: text(&u["kind"]).unwrap_or_default(), certification_jit: text(&manifest["certification_jit"]),
            certified_facts: u["facts"].as_array().ok_or("unit missing facts array")?.clone(),
            certificates: u.as_object().ok_or("unit must be an object")?.iter()
                .filter(|(k, _)| !["id", "pass", "target", "file", "kind", "sites", "facts"].contains(&k.as_str()))
                .map(|(k, v)| (k.clone(), v.clone())).collect(),
            guards: guards(u, &manifest), activation_refusal: (name == "sealed/form_scaffold" && u["data"]["passive"]["version"] != 1).then(|| Reason {
                code: "effectful_form_certification".into(),
                detail: "old effectful form certificate; rebuild for passive admission; keep original".into(),
            }), counts });
    }
    let mut sites = Vec::new();
    for row in rows.into_iter().flatten() {
        let target = text(&row["target"]).unwrap_or_default();
        let row_pass = text(&row["pass"]);
        let ids: Vec<_> = manifest["units"].as_array().into_iter().flatten()
            .filter(|u| row["outcome"] == "lowered" && row["pass"] == u["pass"] && matches_site(u, row, app))
            .filter_map(|u| u["id"].as_u64()).collect();
        let (status, code, detail) = match row["outcome"].as_str() {
            Some("lowered") if ids.is_empty() => (Status::LeftOriginal, "not_emitted".into(),
                "Ledger eligibility did not produce a manifest unit; original code remains".into()),
            Some("lowered") => (Status::Lowered, text(&row["reason"]).unwrap_or_else(|| "lowered".into()), text(&row["detail"]).unwrap_or_default()),
            Some("refused") => (Status::Refused, text(&row["reason"]).unwrap_or_else(|| "unclassified".into()), text(&row["detail"]).unwrap_or_default()),
            _ => (Status::Ledgered, text(&row["reason"]).unwrap_or_else(|| "not_recorded".into()), text(&row["detail"]).unwrap_or_default()),
        };
        sites.push(Site { location: site_location(row, boot.as_ref(), app), target, line: row["line"].as_u64().unwrap_or(0), site: text(&row["site"]).unwrap_or_else(|| "*".into()),
            pass: row_pass, status, reason: Reason { code, detail }, unit_ids: ids, ledger: Some(row.clone()) });
    }
    if let Some(location) = location {
        let (path, line) = location.rsplit_once(':').ok_or("expected path:line")?;
        let line = line.parse::<u64>().ok().filter(|n| *n > 0).ok_or("expected a positive line number")?;
        let path = app.join(path).display().to_string();
        sites.retain(|s| s.location.as_ref().is_some_and(|l| same_path(&l.path, &path, app) && l.line == line));
        if sites.is_empty() {
            sites.push(Site { location: Some(Location { path: path.clone(), line, origin: "query".into() }), target: path, line, site: "*".into(), pass: None, status: Status::LeftOriginal,
                reason: Reason { code: "not_recorded".into(), detail: "No ledger decision at this location; not evidence of a refusal or certification".into() },
                unit_ids: vec![], ledger: None });
        }
        units.retain(|u| sites.iter().any(|s| s.unit_ids.contains(&u.id)));
    }
    if let Some(id) = id {
        units.retain(|u| u.id == id);
        if units.is_empty() { return Err(format!("unit {id} is not in this manifest; refusals have ledger sites, not unit IDs")); }
        sites.retain(|s| s.unit_ids.contains(&id));
    }
    if let Some(pass) = pass {
        units.retain(|u| u.pass == pass);
        sites.retain(|s| s.pass.as_deref() == Some(pass));
    }
    let mut notes = vec!["Build eligibility is not runtime activation. Guards are described, never evaluated. Counters are recorded per unit, not per site.".into()];
    if manifest["files"].as_object().is_some_and(|files| !files.is_empty()) {
        notes.push("Source delivery requires ModuleHooks for late Bootsnap rehook, independently of unit facts; installed identically with LOWRAIL=0. LOWRAIL_UNITS=\"\" installs no hooks or delivery.".into());
    }
    if manifest["selected_passes"].is_null() { notes.push("Exact pass selection was not recorded by this build; it cannot be inferred from successful units or quarantine rows. Rebuild to record it.".into()); }
    if boot.is_none() { notes.push("No facts dump; unit certificates and ledger are still shown, without boot-fact context.".into()); }
    let delivery_refusals = manifest["delivery_refusal"].as_str().map(refusal).into_iter().collect();
    Ok(Report { format: 1, app: app.display().to_string(), artifact_dir: dir.display().to_string(),
        manifest_available: raw.is_some(), ledger_available: ledger.is_some(),
        selected_passes: manifest.get("selected_passes").filter(|v| !v.is_null()).map(|v| serde_json::from_value(v.clone()).map_err(|e| e.to_string())).transpose()?,
        certification_jit: text(&manifest["certification_jit"]), rails_env: text(&manifest["rails_env"]), tier: text(&manifest["tier"]),
        facts: boot.map(|f| FactSummary { path: facts_path.display().to_string(), ruby_description: f.ruby_description, rails_version: f.rails_version, yjit: f.yjit }),
        delivery_refusals, stats: statistics, units, sites, notes })
}

fn site_location(row: &Value, boot: Option<&facts::Facts>, app: &Path) -> Option<Location> {
    let target = row["target"].as_str()?;
    if let Some(line) = row["line"].as_u64().filter(|n| *n > 0) {
        return Some(Location { path: app.join(target).display().to_string(), line, origin: "ledger".into() });
    }
    let boot = boot?;
    // A class-level refusal (e.g. CRM instantiate) has no call-site line.
    // Anchor it only to that exact constant's recorded definition, labeled
    // as such; never attribute the refusal to every method in its file.
    let (location, origin) = if let Some(module) = boot.modules.iter().find(|m| m.name == target) {
        (module.const_source_location.as_deref()?, "boot_constant")
    } else {
        let (receiver, name, singleton) = target.rsplit_once('#').map(|(c, m)| (c, m, false))
            .or_else(|| target.rsplit_once('.').map(|(c, m)| (c, m, true)))?;
        let (_, method) = crate::types::resolve(boot, receiver, name, singleton)?;
        (method.source_location.as_deref()?, "boot_method")
    };
    let (path, line) = facts::schema::split_location(location).filter(|(_, line)| *line > 0)?;
    Some(Location { path: path.into(), line: line as u64, origin: origin.into() })
}

fn same_path(a: &str, b: &str, app: &Path) -> bool {
    let path = |s: &str| { let p = app.join(s); p.canonicalize().unwrap_or(p) };
    path(a) == path(b)
}

fn matches_site(u: &Value, row: &Value, app: &Path) -> bool {
    let target = row["target"].as_str().unwrap_or("");
    if ["file", "target"].iter().any(|k| u[*k].as_str().is_some_and(|p| p == target || same_path(p, target, app))) { return true; }
    let loc = &u["data"]["site"]["source_location"];
    if loc[0].as_str().is_some_and(|p| same_path(p, target, app)) && loc[1] == row["line"] { return true; }
    if u["sealed"]["templates"].as_object().is_some_and(|m| m.keys().any(|p| same_path(p, target, app))) { return true; }
    // Preload units aggregate certified association edges; unrelated refused
    // edges must never inherit their counters (caller checks outcome first).
    u["preload_facts"]["edges"].as_object().is_some_and(|edges| edges.contains_key(row["site"].as_str().unwrap_or("")))
}

fn refusal(detail: &str) -> Reason {
    let code = if detail.starts_with("certification JIT mode mismatch") { "jit_mode_mismatch" }
        else if detail.starts_with("bundlebun_load_order:") { "bundlebun_load_order" }
        else { "runtime_refusal" };
    Reason { code: code.into(), detail: detail.into() }
}

fn read_stats(path: &Path, manifest: Option<&Value>) -> Result<Option<Statistics>, String> {
    let Some(data) = facts::read_json(path)? else { return Ok(None) };
    let (run, binding) = if data.get("report").is_some() {
        if data["format"] != 1 { return Err("unsupported verify stats format".into()); }
        (&data["report"]["on"], if manifest == Some(&data["manifest"]) { "current_manifest" } else { "stale_manifest" })
    } else { (&data, "unbound_snapshot") };
    let mut modes = run["jit_modes"].as_array().cloned().unwrap_or_default();
    if run["jit_mode"].is_object() { modes.push(run["jit_mode"].clone()); }
    let mut refusals = Vec::new();
    for detail in modes.iter().filter_map(|m| m["refusal"].as_str()).chain(run["refusal_reason"].as_str()) {
        if !refusals.iter().any(|r: &Reason| r.detail == detail) { refusals.push(refusal(detail)); }
    }
    Ok(Some(Statistics { source: path.display().to_string(), binding: binding.into(),
        unit_hits: serde_json::from_value(run["unit_hits"].clone()).map_err(|e| format!("invalid unit_hits: {e}"))?,
        unit_fallbacks: serde_json::from_value(run["unit_fallbacks"].clone()).map_err(|e| format!("invalid unit_fallbacks: {e}"))?,
        unit_refusals: serde_json::from_value(run.get("unit_refusals").cloned().unwrap_or_else(|| serde_json::json!({}))).map_err(|e| format!("invalid unit_refusals: {e}"))?,
        jit_modes: modes, refusals }))
}

fn guards(unit: &Value, manifest: &Value) -> Vec<Guard> {
    let mut result = vec![Guard { phase: "admission".into(), requirement: format!("Manifest compatibility, delivery policy and certification JIT mode {}; environment {}",
        manifest["certification_jit"], manifest["rails_env"]) }];
    if manifest["tier"] == "sealed-v1" {
        result.push(Guard { phase: "contract".into(), requirement: "LOWRAIL_SEALED=1, production, sealed-only units and SEAL001–009 no-mutation contract; cached hooks are not completeness proof".into() });
    }
    if unit["facts"].as_array().is_some_and(|f| !f.is_empty()) {
        result.push(Guard { phase: "admission".into(), requirement: "Hook dependency: selecting this unit requires ModuleHooks and ObjectHooks for method-fact invalidation; installed identically with LOWRAIL=0, without activating guards or delivery in that arm".into() });
        result.push(Guard { phase: "call".into(), requirement: "Guard.validate: recorded receiver/method owner, source location, visibility, receiver/subclass/override and optional route facts; original body on false".into() });
    } else {
        result.push(Guard { phase: "admission".into(), requirement: "Hook dependency: none for this unit (no method facts). Other selected units or source delivery may require hooks; sealed status alone does not remove a dependency".into() });
    }
    if unit["pass"] == "sealed/form_scaffold" {
        for (phase, requirement) in [
            ("activation", "Passive v1 certificate: first natural certified form runs original. One atomic read-only witness per process; concurrent prepublication calls run original, failed admission is terminal. No runtime Materialize, requires, schema probes, compiler or hook replay. LOWRAIL=0 has the identical observation seam; recorded unit_refusals are historical pending/refused reasons, not a live admission check"),
            ("call", "FormScaffold.valid?: main Ractor, published admission, seal epoch zero; original model/options/block site, native exact view/model/builder/buffer holders, stock default form builder, English locale, persisted article and blank unpersisted error-free child; otherwise super"),
        ] { result.push(Guard { phase: phase.into(), requirement: requirement.into() }); }
    } else if unit["pass"] == "sealed/link_to" {
        result.push(Guard { phase: "activation".into(), requirement: "Sealed.activate: certified Native.exact_class? primitive, helper dependencies and cached controller view class must already exist; no runtime Materialize, require or view-class construction. Retry at natural request entry; exact source/body/visibility/delivery/literal-table guards remain".into() });
    } else if unit.as_object().is_some_and(|o| o.keys().any(|k| !["id", "kind", "pass", "target", "file", "sites", "facts"].contains(&k.as_str()))) {
        result.push(Guard { phase: "activation".into(), requirement: "Pass-specific runtime certificate and input checks apply; complete recorded payloads are in certificates, not advisory inferred types".into() });
    }
    result
}

impl Report {
    pub fn render(&self) -> String {
        let mut out = format!("explain: {}\nartifact: {}\nselection: {}\ncertification JIT: {}; environment: {}; tier: {}\n",
            self.app, self.artifact_dir, self.selected_passes.as_ref().map(|p| if p.is_empty() { "(none)".into() } else { p.join(", ") }).unwrap_or_else(|| "not recorded".into()),
            self.certification_jit.as_deref().unwrap_or("unknown"), self.rails_env.as_deref().unwrap_or("unknown"), self.tier.as_deref().unwrap_or("guarded"));
        if let Some(f) = &self.facts { out.push_str(&format!("boot facts: {} (Rails {}, yjit={}; advisory, not certification mode)\n", f.path, f.rails_version.as_deref().unwrap_or("unknown"), f.yjit)); }
        for r in &self.delivery_refusals { out.push_str(&format!("delivery refused [{}]: {}\n", r.code, r.detail)); }
        if let Some(s) = &self.stats {
            out.push_str(&format!("recorded stats: {} [{}; not a live guard check]\n", s.source, s.binding));
            for mode in &s.jit_modes { out.push_str(&format!("  observed JIT: {mode}\n")); }
            for r in &s.refusals { out.push_str(&format!("  runtime refused [{}]: {}\n", r.code, r.detail)); }
            for (id, reasons) in &s.unit_refusals {
                for reason in reasons { out.push_str(&format!("  recorded unit {id} activation refused: {reason}\n")); }
            }
        } else { out.push_str("stats: not recorded (unknown, not zero hits)\n"); }
        for u in &self.units {
            out.push_str(&format!("unit {}: lowered (build) {} {}\n", u.id, u.pass, u.target));
            if let Some(r) = &u.activation_refusal { out.push_str(&format!("  current runtime policy refuses [{}]: {}\n", r.code, r.detail)); }
            for guard in &u.guards { out.push_str(&format!("  guard [{}]: {}\n", guard.phase, guard.requirement)); }
            for fact in &u.certified_facts { out.push_str(&format!("  certified fact: {fact}\n")); }
            for (name, payload) in &u.certificates { out.push_str(&format!("  certificate {name}: {} (complete payload in --json)\n", payload.as_object().map(|o| o.keys().cloned().collect::<Vec<_>>().join(", ")).unwrap_or_else(|| "recorded value".into()))); }
            if let Some(c) = &u.counts { out.push_str(&format!("  recorded unit hits={} fallbacks={}\n", c.hits, c.fallbacks)); }
        }
        for site in &self.sites {
            out.push_str(&format!("{}:{} {} {}: {} [{}] {} (units {:?})\n", site.target, site.line,
                site.pass.as_deref().unwrap_or("no pass"), site.site, serde_json::to_value(&site.status).unwrap().as_str().unwrap(),
                site.reason.code, site.reason.detail, site.unit_ids));
            if let Some(l) = &site.location { out.push_str(&format!("  location [{}]: {}:{}\n", l.origin, l.path, l.line)); }
        }
        for note in &self.notes { out.push_str(&format!("note: {note}\n")); }
        out
    }
}

pub fn cli(args: &[String]) -> Result<(), String> {
    let usage = "usage: lowrail explain APP [--dir DIR] [--unit ID | --site PATH:LINE] [--pass NAME] [--stats FILE] [--json]";
    let mut args = args.iter();
    let app = PathBuf::from(args.next().ok_or(usage)?).canonicalize().map_err(|e| e.to_string())?;
    let (mut dir, mut stats, mut id, mut site, mut pass, mut json) = (None, None, None, None, None, false);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--dir" => dir = Some(PathBuf::from(args.next().ok_or(usage)?)),
            "--stats" => stats = Some(PathBuf::from(args.next().ok_or(usage)?)),
            "--unit" => id = Some(args.next().ok_or(usage)?.parse::<u64>().map_err(|_| "--unit needs a nonnegative integer")?),
            "--site" => site = Some(args.next().ok_or(usage)?.as_str()),
            "--pass" => pass = Some(args.next().ok_or(usage)?.as_str()),
            "--json" => json = true,
            _ => return Err(usage.into()),
        }
    }
    if id.is_some() && site.is_some() { return Err("choose --unit or --site".into()); }
    let report = read(&app, dir.as_deref(), stats.as_deref(), id, site, pass)?;
    if json { println!("{}", serde_json::to_string_pretty(&report).unwrap()); }
    else { print!("{}", report.render()); }
    Ok(())
}

pub fn schema() -> Value {
    serde_json::from_str(include_str!("explain.schema.json")).unwrap()
}
