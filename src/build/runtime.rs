//! One booted Ruby builder process; Rust owns ids and artifact writes.
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use serde::Deserialize;
use serde_json::{Value, json};

use crate::{facts, passes::{Builder, Kind, Selection}};

#[derive(Deserialize)]
pub struct Output {
    units: Vec<Value>,
    ledger: Vec<Value>,
    #[serde(default)]
    files: Vec<Source>,
}

#[derive(Deserialize)]
struct Source {
    path: PathBuf,
    original: String,
    parts: Vec<Part>,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum Part { Text(String), Unit(usize) }

pub struct LoweredSource {
    pub path: PathBuf,
    pub original: String,
    pub code: String,
}

pub fn run(app: &Path, env: &str, passes: &Selection, denied: &[Value]) -> Result<Vec<Output>, String> {
    let builders: Vec<_> = passes.iter().filter(|p| p.kind == Kind::Runtime).map(|p| {
        let Builder::Runtime { file, module } = p.builder else { unreachable!() };
        json!({"file": file, "module": module})
    }).collect();
    if builders.is_empty() { return Ok(vec![]); }
    let mut child = Command::new("bundle")
        .args(["exec", "ruby"])
        .arg(facts::gem_dir().join("exe/lowrail-runtime-build"))
        .current_dir(app)
        .env_remove("RUBYOPT")
        .env("RAILS_ENV", env)
        .env("LOWRAIL", "0")
        .stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::inherit())
        .spawn().map_err(|e| format!("runtime builders: {e}"))?;
    let request = json!({"builders": builders, "denied": denied});
    child.stdin.take().unwrap().write_all(request.to_string().as_bytes()).map_err(|e| e.to_string())?;
    let output = child.wait_with_output().map_err(|e| e.to_string())?;
    if !output.status.success() { return Err(format!("runtime builders failed ({})", output.status)); }
    serde_json::from_slice(&output.stdout).map_err(|e| format!("runtime builder response: {e}"))
}

/// Runtime results use local indices, not globally allocated ids. Only typed
/// numeric source parts are remapped; arbitrary source strings stay verbatim.
pub fn merge(units: &mut Vec<Value>, ledger: &mut Vec<Value>, output: Output) -> Result<Vec<LoweredSource>, String> {
    let start = units.iter().filter_map(|u| u["id"].as_u64()).max().map_or(0, |id| id + 1);
    let mut files = Vec::new();
    for source in output.files {
        let mut code = String::new();
        for part in source.parts {
            match part {
                Part::Text(text) => code.push_str(&text),
                Part::Unit(index) => {
                    if index >= output.units.len() { return Err(format!("runtime source refers to missing unit {index}")); }
                    code.push_str(&(start + index as u64).to_string());
                }
            }
        }
        files.push(LoweredSource { path: source.path, original: source.original, code });
    }
    for (index, mut unit) in output.units.into_iter().enumerate() {
        unit["id"] = json!(start + index as u64);
        units.push(unit);
    }
    ledger.extend(output.ledger);
    Ok(files)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn merge_preserves_pass_payloads_refusals_and_source_literals() {
        let mut units = vec![json!({"id": 7, "pass": "route/path", "facts": []})];
        let old_ledger = json!({"pass": "route/path", "outcome": "lowered", "copies": 2});
        let refusal = json!({"pass": "digest/file_memo", "file": "/refined.rb", "outcome": "refined gem source"});
        let mut ledger = vec![old_ledger.clone()];
        let output = serde_json::from_value(json!({
            "units": [{"pass": "digest/file_memo", "facts": ["left"]}, {"pass": "digest/file_memo", "facts": ["right"]}],
            "ledger": [refusal.clone()],
            "files": [{"path": "/gem.rb", "original": "original", "parts": ["utf8: λ; literal='0'; hit(", 1, "); hit(", 0, ")\n"]}]
        })).unwrap();
        let files = merge(&mut units, &mut ledger, output).unwrap();
        assert_eq!(files[0].code, "utf8: λ; literal='0'; hit(9); hit(8)\n");
        assert_eq!(files[0].original, "original");
        assert_eq!(files[0].path, PathBuf::from("/gem.rb"));
        let next = serde_json::from_value(json!({"units": [{"pass": "active_record/preload_plans", "facts": []}], "ledger": []})).unwrap();
        assert!(merge(&mut units, &mut ledger, next).unwrap().is_empty());
        assert_eq!(units.iter().map(|u| u["id"].as_u64().unwrap()).collect::<Vec<_>>(), [7, 8, 9, 10]);
        assert_eq!(units[1]["facts"], json!(["left"]));
        assert_eq!(units[2]["facts"], json!(["right"]));
        assert_eq!(ledger, [old_ledger, refusal]);
        let empty = serde_json::from_value(json!({"units": [], "ledger": [{"outcome": "refused"}]})).unwrap();
        merge(&mut units, &mut ledger, empty).unwrap();
        assert_eq!(units.len(), 4);
        assert_eq!(ledger.last().unwrap()["outcome"], "refused");
    }
}
