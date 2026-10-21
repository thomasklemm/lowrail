//! Verification has a separate fresh, passive discovery path. It never reads
//! materialized facts.json, starts an oracle, or replaces a production artifact.
use std::path::Path;
use std::process::Command;

use serde_json::json;

use super::{runtime, write_atomic};
use crate::{facts, passes::Selection};

pub fn build(app: &Path, jit: Option<&str>) -> Result<String, String> {
    if std::env::var("PARALLEL_WORKERS").as_deref() != Ok("1") {
        return Err("--verify-test requires explicit PARALLEL_WORKERS=1; no parallel certification".into());
    }
    let dir = app.join(".lowrail/verification-test");
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let denied = facts::read_json(&app.join(".lowrail/denylist.json"))?.unwrap_or(json!([]));
    let denied = denied.as_array().ok_or("denylist must be an array")?;
    let mode = jit.unwrap_or("interpreter");
    // Unlike ordinary build JIT preparation, this mode observes the app's
    // actual startup policy. It never changes config.yjit or enables a JIT.
    let outputs = runtime::run(app, "test", &Selection::sealed(), denied, mode, true)?;
    let mut units = Vec::new();
    let mut ledger = Vec::new();
    let mut files = Vec::new();
    let mut certificate = None;
    for mut output in outputs {
        if let Some(data) = output.verification_test.take() {
            certificate = Some(data);
        }
        for source in runtime::merge(&mut units, &mut ledger, output)? {
            let dest = dir.join(format!("source-{}.rb", files.len()));
            let original = dest.with_extension("rb.orig");
            std::fs::write(&dest, source.code).map_err(|e| e.to_string())?;
            std::fs::write(&original, source.original).map_err(|e| e.to_string())?;
            files.push(json!({"path": source.path, "lowered": dest, "original": original}));
        }
    }
    let certificate = certificate.ok_or("missing verification-only test certificate")?;
    write_atomic(&dir.join("verification-facts.json"), &serde_json::to_string_pretty(&certificate).unwrap())?;
    let input = json!({"out": dir, "app_root": app, "rails_env": "test",
        "certification_jit": mode, "tier": "sealed-test-v1", "verification_test": certificate,
        "files": files, "templates": {}, "units": units});
    let path = dir.join("units.json");
    write_atomic(&path, &serde_json::to_string_pretty(&input).unwrap())?;
    write_atomic(&dir.join("ledger.json"), &serde_json::to_string_pretty(&ledger).unwrap())?;
    let status = Command::new("bundle").args(["exec", "ruby"])
        .arg(facts::gem_dir().join("exe/lowrail-compile")).arg(path)
        .current_dir(app).env_remove("RUBYOPT").env("RAILS_ENV", "test").env("LOWRAIL", "0")
        .status().map_err(|e| format!("verification compiler: {e}"))?;
    if !status.success() { return Err("verification compiler/own-suite failed".into()); }
    Ok(format!("verification-only test artifact: {}\nFresh natural own-suite discovery; production facts/artifacts untouched. See ledger for refused passes. Runtime requires LOWRAIL_SEALED=1 LOWRAIL_VERIFY_TEST=1 and LOWRAIL_DIR pointing here.", dir.display()))
}
