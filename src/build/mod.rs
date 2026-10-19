//! `lowrail build APP`: lowers what it can and writes `.lowrail/manifest.json`
//! (see docs/FORMATS.md). Today this covers ERB templates (view lowering);
//! Ruby files go through `gem/exe/lowrail-compile` once a pass targets them.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use serde_json::{Value, json};

use crate::facts;
use crate::lower::oracle::RubyOracle;
use crate::lower::view;

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut app = None;
    let mut env = "test".to_string();
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--env" => env = it.next().ok_or("--env needs a value")?.clone(),
            _ if app.is_none() => app = Some(PathBuf::from(a)),
            _ => return Err(format!("unexpected argument {a}")),
        }
    }
    let app = app.ok_or("usage: lowrail build APP [--env test|production]")?;
    let app = app.canonicalize().map_err(|e| format!("{}: {e}", app.display()))?;
    let report = build(&app, &env)?;
    println!("{report}");
    Ok(())
}

pub fn build(app: &Path, env: &str) -> Result<String, String> {
    let dir = app.join(".lowrail");
    let facts_path = dir.join("facts.json");
    if !facts_path.exists() {
        facts::dump(app, &facts_path)?;
    }
    let facts = facts::load(&facts_path)?;
    let mut oracle = RubyOracle::start(app, env)?;
    let probe = oracle_info(&mut oracle)?;

    // Units `lowrail verify --bisect` found to change outcomes stay unlowered.
    let denied: Vec<(String, String)> = std::fs::read_to_string(dir.join("denylist.json"))
        .ok()
        .and_then(|s| serde_json::from_str::<Vec<Value>>(&s).ok())
        .unwrap_or_default()
        .iter()
        .map(|d| (d["file"].as_str().unwrap_or("").to_string(), d["pass"].as_str().unwrap_or("").to_string()))
        .collect();
    let mut templates = BTreeMap::new();
    let mut units = Vec::new();
    let mut ledger = Vec::new();
    for t in &facts.templates {
        if t.handler != "ActionView::Template::Handlers::ERB" {
            continue;
        }
        if denied.iter().any(|(f, p)| f == &t.identifier && p == "view/link_to") {
            ledger.push(json!({"template": t.identifier, "line": 0, "helper": "*", "outcome": "denylisted by verify --bisect"}));
            continue;
        }
        let locals = partial_locals(t.virtual_path.as_deref().unwrap_or(""));
        let unit = units.len();
        let lowered = view::lower_template(&t.code, &locals, unit, &mut oracle);
        for s in &lowered.sites {
            ledger.push(json!({"template": t.identifier, "line": s.line, "helper": s.helper, "outcome": s.outcome}));
        }
        if lowered.lowered_count() == 0 {
            continue;
        }
        let facts: Vec<Value> = lowered
            .deps
            .iter()
            .map(|d| json!({"receiver": d.receiver, "method": d.method, "owner": d.owner, "source_location": d.source_location, "visibility": d.visibility}))
            .collect();
        units.push(json!({"id": unit, "kind": "template", "file": t.identifier, "pass": "view/link_to", "sites": lowered.lowered_count(), "facts": facts}));
        templates.insert(t.identifier.clone(), json!({"source_sha256": t.source_sha256, "code": lowered.code, "unit": unit}));
    }

    let manifest = json!({
        "format": 1,
        "rails_env": env,
        "ruby_description": probe.0,
        "compile_option": probe.1,
        "files": {},
        "templates": templates,
        "units": units,
    });
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    write_atomic(&dir.join("manifest.json"), &serde_json::to_string_pretty(&manifest).unwrap())?;
    write_atomic(&dir.join("ledger.json"), &serde_json::to_string_pretty(&ledger).unwrap())?;
    let lowered_sites: usize = ledger.iter().filter(|l| l["outcome"] == "lowered").count();
    Ok(format!(
        "{} templates lowered ({} units), {} of {} helper sites lowered; ledger: {}",
        templates.len(),
        units.len(),
        lowered_sites,
        ledger.len(),
        dir.join("ledger.json").display()
    ))
}

/// Ruby description and compile-option fingerprint as the runtime computes
/// them, so a manifest from another Ruby is ignored.
fn oracle_info(oracle: &mut RubyOracle) -> Result<(String, String), String> {
    use crate::lower::oracle::Oracle;
    let (desc, _) = oracle.eval_string("RUBY_DESCRIPTION")?;
    let (fp, _) = oracle.eval_string(
        "require 'digest'; Digest::SHA256.hexdigest(RubyVM::InstructionSequence.compile_option.sort_by { |k, _| k.to_s }.inspect)",
    )?;
    Ok((desc, fp))
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
