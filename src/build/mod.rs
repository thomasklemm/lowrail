//! `lowrail build APP`: lowers what it can and writes `.lowrail/manifest.json`
//! (see docs/FORMATS.md). Passes: `view/link_to` and `route/path` on ERB
//! templates (served through the template seam), `route/path` on Ruby files
//! under app/ (lowered sources compiled by `gem/exe/lowrail-compile` and
//! served through load_iseq). Every site a pass looked at is in ledger.json.

mod ledger;
mod runtime;

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;

use serde_json::{Value, json};

use crate::facts;
use crate::lower::oracle::RubyOracle;
use crate::lower::{memo, route, view};
use crate::passes::{Builder, Kind, REGISTRY, Selection};

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut app = None;
    let mut env = "test".to_string();
    let mut passes = Selection::default();
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--env" => env = it.next().ok_or("--env needs a value")?.clone(),
            "--passes" => passes = Selection::parse(it.next().ok_or("--passes needs a value")?)?,
            _ if !a.starts_with('-') && app.is_none() => app = Some(PathBuf::from(a)),
            _ => return Err(format!("unexpected argument {a}")),
        }
    }
    let app = app.ok_or("usage: lowrail build APP [--env test|production] [--passes default,+name,-name]")?;
    let app = app.canonicalize().map_err(|e| format!("{}: {e}", app.display()))?;
    println!("{}", build(&app, &env, &passes)?);
    Ok(())
}

pub fn build(app: &Path, env: &str, passes: &Selection) -> Result<String, String> {
    let dir = app.join(".lowrail");
    let facts_path = dir.join("facts.json");
    if !facts_path.exists() {
        facts::dump(app, &facts_path)?;
    }
    let facts = facts::load(&facts_path)?;
    // Shared advisory input, available before any builder runs. It grants
    // no authority to lower; pass-specific certificates still own that.
    let typed_facts = crate::types::TypeModel::load(app, &facts)?.typed_facts();
    write_atomic(&dir.join("typed_facts.json"), &serde_json::to_string_pretty(&typed_facts).unwrap())?;
    let mut oracle = RubyOracle::start(app, env)?;
    let mut routes = route::Cache::default();
    let mut memo_certificate = None;
    let mut digest_certificate = None;

    // Units `lowrail verify --bisect` found to change outcomes stay unlowered
    // (denylist entries name a file and a pass).
    let denied: Vec<Value> = std::fs::read_to_string(dir.join("denylist.json"))
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default();
    let is_denied = |file: &str, pass: &str| denied.iter().any(|d| d["file"] == file && d["pass"] == pass);

    let mut templates = BTreeMap::new();
    let mut units: Vec<Value> = Vec::new();
    let mut ledger: Vec<Value> = Vec::new();
    for t in &facts.templates {
        if t.handler != "ActionView::Template::Handlers::ERB" {
            continue;
        }
        let locals = partial_locals(t.virtual_path.as_deref().unwrap_or(""));
        let mut code = t.code.clone();
        let mut ids = Vec::new();

        // Registry order lets routes see link_to's fast AND fallback branches.
        for pass in passes.iter().filter(|p| matches!(p.builder, Builder::View | Builder::Route)) {
            if is_denied(&t.identifier, pass.name) {
                ledger.push(denied_entry("template", &t.identifier, pass.name));
                continue;
            }
            let unit = units.len();
            let lowered = match pass.builder {
                Builder::View => view::lower_template(&code, &locals, unit, &mut oracle),
                Builder::Route => route::lower(&code, &route::Mode::Template { locals: &locals }, unit, &mut oracle, &mut routes),
                _ => unreachable!(),
            };
            record(&mut ledger, "template", &t.identifier, pass.name, &lowered.sites);
            if lowered.lowered_count() > 0 {
                units.push(unit_json(unit, "template", &t.identifier, pass.name, &lowered));
                ids.push(unit);
                code = lowered.code;
            }
        }
        if !ids.is_empty() {
            templates.insert(t.identifier.clone(), json!({"source_sha256": t.source_sha256, "code": code, "units": ids}));
        }
    }

    // Ruby files under app/: route helpers in controllers, helpers, models,
    // mailers, jobs. Lowered sources go through lowrail-compile, which checks
    // the file still has the bytes it was lowered from (the `.orig` copy).
    let src_dir = dir.join("src");
    let _ = std::fs::remove_dir_all(&src_dir);
    std::fs::create_dir_all(&src_dir).map_err(|e| e.to_string())?;
    let mut files = Vec::new();
    for path in ruby_files(&app.join("app")) {
        let Ok(original) = std::fs::read_to_string(&path) else { continue };
        let file = path.display().to_string();
        let mut code = original.clone();
        let before = units.len();
        for pass in passes.iter().filter(|p| p.kind == Kind::Source && !matches!(p.builder, Builder::View)) {
            if is_denied(&file, pass.name) {
                ledger.push(denied_entry("file", &file, pass.name));
                continue;
            }
            let unit = units.len();
            match pass.builder {
                Builder::Route => {
                    let lowered = route::lower(&code, &route::Mode::RubyFile, unit, &mut oracle, &mut routes);
                    record(&mut ledger, "file", &file, pass.name, &lowered.sites);
                    if lowered.lowered_count() > 0 {
                        units.push(unit_json(unit, "file", &file, pass.name, &lowered));
                        code = lowered.code;
                    }
                }
                Builder::Memo(intrinsic) => {
                    let cache = match intrinsic { memo::Intrinsic::UriJoin => &mut memo_certificate, memo::Intrinsic::Sha256 => &mut digest_certificate };
                    let lowered = memo::lower(&code, unit, &mut oracle, cache, intrinsic);
                    record(&mut ledger, "file", &file, pass.name, &lowered.sites);
                    let sites = lowered.sites.iter().filter(|s| s.outcome == "lowered").count();
                    if sites > 0 {
                        let certificate = lowered.certificate.unwrap();
                        units.push(json!({"id": unit, "kind": "file", "file": file, "pass": pass.name,
                            "sites": sites, "facts": certificate["facts"], "memo": certificate}));
                        code = lowered.code;
                    }
                }
                _ => unreachable!(),
            }
        }
        if units.len() == before { continue; }
        let stem = path.strip_prefix(app).unwrap_or(&path).display().to_string().replace('/', "__");
        let lowered_path = src_dir.join(&stem);
        let original_path = src_dir.join(format!("{stem}.orig"));
        std::fs::write(&lowered_path, &code).map_err(|e| e.to_string())?;
        std::fs::write(&original_path, &original).map_err(|e| e.to_string())?;
        files.push(json!({"path": file, "lowered": lowered_path, "original": original_path}));
    }
    drop(oracle);

    for output in runtime::run(app, env, passes, &denied)? {
        let sources = runtime::merge(&mut units, &mut ledger, output)?;
        for source in sources {
            let dest = src_dir.join(format!("runtime__{}.rb", files.len()));
            let original = dest.with_extension("rb.orig");
            std::fs::write(&dest, source.code).map_err(|e| e.to_string())?;
            std::fs::write(&original, source.original).map_err(|e| e.to_string())?;
            files.push(json!({"path": source.path, "lowered": dest, "original": original}));
        }
    }
    let ledger: Vec<_> = ledger.into_iter().map(ledger::normalize).collect();
    let input = json!({
        "out": dir,
        "rails_env": env,
        "files": files,
        "templates": templates,
        "units": units,
        "typed_facts": typed_facts,
    });
    let input_path = dir.join("units.json");
    write_atomic(&input_path, &serde_json::to_string_pretty(&input).unwrap())?;
    write_atomic(&dir.join("ledger.json"), &serde_json::to_string_pretty(&ledger).unwrap())?;
    let status = Command::new("bundle")
        .args(["exec", "ruby"])
        .arg(facts::gem_dir().join("exe/lowrail-compile"))
        .arg(&input_path)
        .current_dir(app)
        .env_remove("RUBYOPT")
        .status()
        .map_err(|e| format!("running lowrail-compile: {e}"))?;
    if !status.success() {
        return Err("lowrail-compile failed".into());
    }
    let manifest: Value = serde_json::from_slice(&std::fs::read(dir.join("manifest.json")).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?;
    Ok(summary(&ledger, manifest["units"].as_array().unwrap(), templates.len(), manifest["files"].as_object().map_or(0, |f| f.len()), &dir))
}

fn summary(ledger: &[Value], units: &[Value], templates: usize, files: usize, dir: &Path) -> String {
    let mut s = String::new();
    for pass in REGISTRY.iter().map(|p| p.name) {
        let sites: Vec<&Value> = ledger.iter().filter(|l| l["pass"] == pass).collect();
        let lowered = sites.iter().filter(|l| l["outcome"] == "lowered").count();
        let n_units = units.iter().filter(|u| u["pass"] == pass).count();
        s.push_str(&format!("{pass}: {lowered} of {} sites lowered, {n_units} units\n", sites.len()));
    }
    let mut reasons = BTreeMap::new();
    for l in ledger.iter().filter(|l| l["outcome"] == "refused") {
        *reasons.entry((l["pass"].as_str().unwrap(), l["reason"].as_str().unwrap())).or_insert(0) += 1;
    }
    if !reasons.is_empty() {
        s.push_str("Refusals (unique ledger sites; see detail/copies in ledger):\n  count  pass                            reason\n");
    }
    for ((pass, reason), n) in reasons {
        s.push_str(&format!("  {n:5}  {pass:32} {reason}\n"));
    }
    s.push_str(&format!("{templates} templates and {files} Ruby files lowered; ledger: {}", dir.join("ledger.json").display()));
    s
}

fn denied_entry(key: &str, file: &str, pass: &str) -> Value {
    json!({key: file, "line": 0, "pass": pass, "helper": "*", "outcome": "denylisted by verify --bisect"})
}

fn unit_json(id: usize, kind: &str, file: &str, pass: &str, lowered: &view::Lowered) -> Value {
    json!({"id": id, "kind": kind, "file": file, "pass": pass, "sites": lowered.lowered_count(), "facts": lowered.deps})
}

/// One ledger entry per site; identical entries (a call copied into both
/// branches of a lowered link_to) are merged with a count.
fn record(ledger: &mut Vec<Value>, key: &str, file: &str, pass: &str, sites: &[view::Site]) {
    let mut seen: BTreeMap<(usize, String, String), usize> = BTreeMap::new();
    for s in sites {
        *seen.entry((s.line, s.helper.clone(), s.outcome.clone())).or_default() += 1;
    }
    for ((line, helper, outcome), n) in seen {
        let mut e = json!({key: file, "line": line, "pass": pass, "helper": helper, "outcome": outcome});
        if n > 1 {
            e["copies"] = json!(n);
        }
        ledger.push(e);
    }
}

/// `*.rb` under app/, except app/assets and app/javascript.
fn ruby_files(dir: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    let mut stack = vec![dir.to_path_buf()];
    while let Some(d) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&d) else { continue };
        for e in entries.flatten() {
            let p = e.path();
            let name = e.file_name().to_string_lossy().into_owned();
            if p.is_dir() {
                if d != dir || !matches!(name.as_str(), "assets" | "javascript") {
                    stack.push(p);
                }
            } else if name.ends_with(".rb") {
                out.push(p);
            }
        }
    }
    out.sort();
    out
}

/// Locals a partial conventionally receives: `articles/_article` →
/// `article`, `article_counter`, `article_iteration`.
fn partial_locals(virtual_path: &str) -> Vec<String> {
    let base = virtual_path.rsplit('/').next().unwrap_or("");
    match base.strip_prefix('_') {
        Some(name) if !name.is_empty() => vec![name.to_string(), format!("{name}_counter"), format!("{name}_iteration")],
        _ => vec![],
    }
}

fn write_atomic(path: &Path, content: &str) -> Result<(), String> {
    let tmp = path.with_extension("tmp");
    std::fs::write(&tmp, content).map_err(|e| e.to_string())?;
    std::fs::rename(&tmp, path).map_err(|e| e.to_string())
}
