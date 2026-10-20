//! `lowrail build APP`: lowers what it can and writes `.lowrail/manifest.json`
//! (see docs/FORMATS.md). Passes: `view/link_to` and `route/path` on ERB
//! templates (served through the template seam), `route/path` on Ruby files
//! under app/ (lowered sources compiled by `gem/exe/lowrail-compile` and
//! served through load_iseq). Every site a pass looked at is in ledger.json.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;

use serde_json::{Value, json};

use crate::facts;
use crate::lower::oracle::RubyOracle;
use crate::lower::{route, view};

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut app = None;
    let mut env = "test".to_string();
    let mut preload = false;
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--env" => env = it.next().ok_or("--env needs a value")?.clone(),
            // Opt-in: measured slower on uncached Campfire (docs/passes/preload-plans.md).
            "--preload-plans" => preload = true,
            _ if app.is_none() => app = Some(PathBuf::from(a)),
            _ => return Err(format!("unexpected argument {a}")),
        }
    }
    let app = app.ok_or("usage: lowrail build APP [--env test|production] [--preload-plans]")?;
    let app = app.canonicalize().map_err(|e| format!("{}: {e}", app.display()))?;
    let report = build(&app, &env, preload)?;
    println!("{report}");
    Ok(())
}

pub fn build(app: &Path, env: &str, preload: bool) -> Result<String, String> {
    let dir = app.join(".lowrail");
    let facts_path = dir.join("facts.json");
    if !facts_path.exists() {
        facts::dump(app, &facts_path)?;
    }
    let facts = facts::load(&facts_path)?;
    let mut oracle = RubyOracle::start(app, env)?;
    let mut routes = route::Cache::default();

    // Units `lowrail verify --bisect` found to change outcomes stay unlowered
    // (denylist entries name a file and a pass).
    let denied: Vec<(String, String)> = std::fs::read_to_string(dir.join("denylist.json"))
        .ok()
        .and_then(|s| serde_json::from_str::<Vec<Value>>(&s).ok())
        .unwrap_or_default()
        .iter()
        .map(|d| (d["file"].as_str().unwrap_or("").to_string(), d["pass"].as_str().unwrap_or("").to_string()))
        .collect();
    let is_denied = |file: &str, pass: &str| denied.iter().any(|(f, p)| f == file && p == pass);

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

        let unit = units.len();
        if is_denied(&t.identifier, "view/link_to") {
            ledger.push(denied_entry("template", &t.identifier, "view/link_to"));
        } else {
            let lowered = view::lower_template(&code, &locals, unit, &mut oracle);
            record(&mut ledger, "template", &t.identifier, "view/link_to", &lowered.sites);
            if lowered.lowered_count() > 0 {
                units.push(unit_json(unit, "template", &t.identifier, "view/link_to", &lowered));
                ids.push(unit);
                code = lowered.code;
            }
        }

        // Runs on the link_to output too, so route helpers inside its fast
        // path are specialized as well.
        let unit = units.len();
        if is_denied(&t.identifier, "route/path") {
            ledger.push(denied_entry("template", &t.identifier, "route/path"));
        } else {
            let lowered = route::lower(&code, &route::Mode::Template { locals: &locals }, unit, &mut oracle, &mut routes);
            record(&mut ledger, "template", &t.identifier, "route/path", &lowered.sites);
            if lowered.lowered_count() > 0 {
                units.push(unit_json(unit, "template", &t.identifier, "route/path", &lowered));
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
        if is_denied(&file, "route/path") {
            ledger.push(denied_entry("file", &file, "route/path"));
            continue;
        }
        let unit = units.len();
        let lowered = route::lower(&original, &route::Mode::RubyFile, unit, &mut oracle, &mut routes);
        record(&mut ledger, "file", &file, "route/path", &lowered.sites);
        if lowered.lowered_count() == 0 {
            continue;
        }
        let stem = path.strip_prefix(app).unwrap_or(&path).display().to_string().replace('/', "__");
        let lowered_path = src_dir.join(&stem);
        let original_path = src_dir.join(format!("{stem}.orig"));
        std::fs::write(&lowered_path, &lowered.code).map_err(|e| e.to_string())?;
        std::fs::write(&original_path, &original).map_err(|e| e.to_string())?;
        files.push(json!({"path": file, "lowered": lowered_path, "original": original_path}));
        units.push(unit_json(unit, "file", &file, "route/path", &lowered));
    }
    drop(oracle);

    let input = json!({
        "out": dir,
        "rails_env": env,
        "files": files,
        "templates": templates,
        "units": units,
    });
    let input_path = dir.join("units.json");
    write_atomic(&input_path, &serde_json::to_string_pretty(&input).unwrap())?;
    write_atomic(&dir.join("ledger.json"), &serde_json::to_string_pretty(&ledger).unwrap())?;
    let status = Command::new("ruby")
        .arg(facts::gem_dir().join("exe/lowrail-compile"))
        .arg(&input_path)
        .current_dir(app)
        .env_remove("RUBYOPT")
        .status()
        .map_err(|e| format!("running lowrail-compile: {e}"))?;
    if !status.success() {
        return Err("lowrail-compile failed".into());
    }
    if !preload {
        return Ok(summary(&ledger, &units, templates.len(), files.len(), &dir));
    }
    let preload_status = Command::new("bundle")
        .args(["exec", "ruby"])
        .arg(facts::gem_dir().join("exe/lowrail-preload-build"))
        .arg(&dir)
        .current_dir(app)
        .env("RAILS_ENV", env)
        .env("LOWRAIL", "0")
        .status()
        .map_err(|e| format!("preload plan facts: {e}"))?;
    if !preload_status.success() {
        return Err(format!("preload plan facts failed ({preload_status})"));
    }
    Ok(summary(&ledger, &units, templates.len(), files.len(), &dir))
}

fn summary(ledger: &[Value], units: &[Value], templates: usize, files: usize, dir: &Path) -> String {
    let mut s = String::new();
    for pass in ["view/link_to", "route/path"] {
        let sites: Vec<&Value> = ledger.iter().filter(|l| l["pass"] == pass).collect();
        let lowered = sites.iter().filter(|l| l["outcome"] == "lowered").count();
        let n_units = units.iter().filter(|u| u["pass"] == pass).count();
        s.push_str(&format!("{pass}: {lowered} of {} sites lowered, {n_units} units\n", sites.len()));
    }
    let mut reasons: BTreeMap<String, usize> = BTreeMap::new();
    for l in ledger.iter().filter(|l| l["outcome"] != "lowered") {
        *reasons.entry(format!("{}: {}", l["pass"].as_str().unwrap_or(""), l["outcome"].as_str().unwrap_or(""))).or_default() += 1;
    }
    for (r, n) in reasons {
        s.push_str(&format!("  {n:4}  {r}\n"));
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
