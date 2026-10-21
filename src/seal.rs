//! Advisory post-boot contract census, separate from default-tier verification.
use serde_json::{Value, json};
use std::path::{Path, PathBuf};
use std::process::Command;

pub fn cli(args: &[String]) -> Result<(), String> {
    let usage = "usage: lowrail seal-check APP [--static | --targets Class,Module] [-- TEST COMMAND...]";
    let mut args = args.iter();
    let app = PathBuf::from(args.next().ok_or(usage)?).canonicalize().map_err(|e| e.to_string())?;
    let mut targets = None;
    let mut static_only = false;
    let mut cmd = vec!["bin/rails".to_string(), "test".to_string()];
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--static" => static_only = true,
            "--targets" => targets = Some(args.next().ok_or(usage)?.clone()),
            "--" => { cmd = args.cloned().collect(); break; }
            _ => return Err(usage.into()),
        }
    }
    if static_only { return static_check(&app).map(|_| ()); }
    if cmd.is_empty() { return Err("test command must not be empty".into()); }
    let dir = app.join(".lowrail/seal-check");
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    for entry in std::fs::read_dir(&dir).map_err(|e| e.to_string())?.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if name.starts_with("seal-") && name.ends_with(".json") {
            std::fs::remove_file(entry.path()).map_err(|e| e.to_string())?;
        }
    }
    let mut command = Command::new(&cmd[0]);
    command.args(&cmd[1..]).current_dir(&app)
        .env("LOWRAIL", "0")
        .env("LOWRAIL_SEAL_CHECK", &dir).env("LOWRAIL_SEAL_ROOT", &app)
        .env_remove("LOWRAIL_SEAL_TARGETS")
        .env("PARALLEL_WORKERS", "1")
        .env("RUBYOPT", format!("{} -I{} -rlowrail/seal", std::env::var("RUBYOPT").unwrap_or_default(), crate::facts::gem_dir().join("lib").display()));
    if let Some(targets) = targets { command.env("LOWRAIL_SEAL_TARGETS", targets); }
    let status = command.status().map_err(|e| format!("running {}: {e}", cmd.join(" ")))?;
    let mut processes = vec![];
    let mut ledger = vec![];
    let mut tests = serde_json::Map::new();
    let mut patterns = std::collections::BTreeMap::<String, usize>::new();
    let mut classifications = std::collections::BTreeMap::<String, usize>::new();
    for entry in std::fs::read_dir(&dir).map_err(|e| e.to_string())?.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if !name.starts_with("seal-") || !name.ends_with(".json") { continue; }
        let data: Value = serde_json::from_slice(&std::fs::read(entry.path()).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?;
        if let Some(rows) = data["ledger"].as_array() {
            for row in rows {
                *patterns.entry(row["pattern"].as_str().unwrap_or("unknown").into()).or_default() += 1;
                let key = format!("{}/{}", row["confidence"].as_str().unwrap_or("unknown"),
                    row["classification"]["kind"].as_str().unwrap_or("needs_review"));
                *classifications.entry(key).or_default() += 1;
                ledger.push(row.clone());
            }
        }
        if let Some(rows) = data["tests"].as_object() { tests.extend(rows.clone()); }
        processes.push(data);
    }
    let sealed = processes.iter().any(|p| p["sealed"] == true);
    let complete = sealed && !tests.is_empty() && processes.iter().all(|p| p["errors"].as_array().is_some_and(|e| e.is_empty()));
    let report = json!({"format":1,"command":cmd,"exit_ok":status.success(),"complete":complete,
        "patterns":patterns,"classifications":classifications,"tests":tests,"ledger":ledger,"processes":processes});
    let path = app.join(".lowrail/seal.json");
    std::fs::write(&path, serde_json::to_vec_pretty(&report).unwrap()).map_err(|e| e.to_string())?;
    println!("seal ledger: {}\n{} observations; {} tests; complete: {}", path.display(), ledger.len(), tests.len(), complete);
    for (pattern, count) in patterns { println!("  {count:>6} {pattern}"); }
    for (classification, count) in classifications { println!("  {count:>6} {classification}"); }
    println!("Advisory only: mutations deopt, not test failures; no detection-completeness or speed claim.");
    if !status.success() { return Err("app test command failed (ledger retained)".into()); }
    if !complete { return Err("seal census incomplete: no sealed tests or materialization errors (see ledger)".into()); }
    Ok(())
}

pub fn static_check(app: &Path) -> Result<Value, String> {
    let path = app.join(".lowrail/seal-static.json");
    std::fs::create_dir_all(path.parent().unwrap()).map_err(|e| e.to_string())?;
    let status = Command::new("bundle").args(["exec", "ruby"])
        .arg(crate::facts::gem_dir().join("exe/lowrail-seal-static"))
        .arg(app).arg(&path).current_dir(app).env("LOWRAIL", "0")
        .status().map_err(|e| e.to_string())?;
    if !status.success() { return Err("static seal pre-check failed".into()); }
    let report: Value = serde_json::from_slice(&std::fs::read(&path).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?;
    println!("static hints: {}", path.display());
    for hint in report["hints"].as_array().into_iter().flatten() {
        println!("  {} hint {}:{} [{}] {}", hint["rule"].as_str().unwrap_or("?"),
            hint["file"].as_str().unwrap_or("?"), hint["line"], hint["origin"]["kind"].as_str().unwrap_or("?"),
            hint["remedy"].as_str().unwrap_or("?"));
    }
    if report["errors"].as_array().is_none_or(|e| !e.is_empty()) { return Err("static scan incomplete; see parse errors in JSON".into()); }
    Ok(report)
}

pub fn doctor(args: &[String]) -> Result<(), String> {
    let usage = "usage: lowrail doctor APP [--seal-check] [--trace-check [--path PATH]] [-- TEST COMMAND...]";
    let mut args = args.iter();
    let app = PathBuf::from(args.next().ok_or(usage)?).canonicalize().map_err(|e| e.to_string())?;
    let mut dynamic = false;
    let mut trace_check = false;
    let mut request_path = None;
    let mut cmd = vec!["bin/rails".to_string(), "test".to_string()];
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--seal-check" => dynamic = true,
            "--trace-check" => trace_check = true,
            "--path" => request_path = Some(args.next().ok_or(usage)?),
            "--" => { cmd = args.cloned().collect(); break; }
            _ => return Err(usage.into()),
        }
    }
    if request_path.is_some_and(|path| !trace_check || !path.starts_with('/')) { return Err(usage.into()); }
    if cmd.is_empty() { return Err("test command must not be empty".into()); }
    println!("doctor: 1. boot (LOWRAIL=0)");
    let mut boot_command = Command::new("bundle");
    boot_command.args(["exec", "ruby"]);
    std::fs::create_dir_all(app.join(".lowrail")).map_err(|e| e.to_string())?;
    boot_command.arg(crate::facts::gem_dir().join("exe/lowrail-doctor-trace"))
        .arg(app.join(".lowrail/doctor-trace.json"))
        .env_remove("LOWRAIL_OUTCOMES").env_remove("LOWRAIL_SEAL_CHECK")
        .env_remove("LOWRAIL_STATS").env_remove("LOWRAIL_VERIFY_LOADS");
    if let Some(path) = request_path { boot_command.arg(path); }
    if !trace_check { boot_command.arg("--mode-only"); }
    let boot = boot_command.current_dir(&app).env("LOWRAIL", "0")
        .status().map_err(|e| e.to_string())?.success();
    println!("doctor: 2. baseline suite (LOWRAIL=0)");
    let baseline = if boot { Some(Command::new(&cmd[0]).args(&cmd[1..]).current_dir(&app)
        .env("LOWRAIL", "0").env("PARALLEL_WORKERS", "1").status().map_err(|e| e.to_string())?.success()) } else { None };
    println!("doctor: 3. static hints (no test run)");
    let mut static_report = static_check(&app);
    println!("doctor: 4. seal-check {}", if dynamic && baseline == Some(true) { "requested" } else { "not run" });
    let dynamic_error = if dynamic && baseline == Some(true) {
        let mut check_args = vec![app.display().to_string(), "--".into()];
        check_args.extend(cmd.clone());
        cli(&check_args).err()
    } else { None };
    let read = |name: &str| -> Result<Value, String> {
        let path = app.join(".lowrail").join(name);
        if !path.exists() { return Ok(Value::Null); }
        serde_json::from_slice(&std::fs::read(path).map_err(|e| e.to_string())?).map_err(|e| e.to_string())
    };
    // Rerender comparison after a newly requested dynamic run, without rerunning tests.
    let seal_ran = dynamic && baseline == Some(true);
    if seal_ran && dynamic_error.is_none() { static_report = static_check(&app); }
    let static_error = static_report.as_ref().err().cloned();
    println!("doctor: 5. guarded refusals");
    let ledger = read("ledger.json")?;
    let mut refusals = std::collections::BTreeMap::<String, Vec<Value>>::new();
    for row in ledger.as_array().into_iter().flatten() {
        if row["outcome"] == "lowered" { continue; }
        let reason = row["reason"].as_str().or(row["outcome"].as_str()).unwrap_or("unknown");
        refusals.entry(reason.into()).or_default().push(row.clone());
    }
    for (reason, rows) in &refusals { println!("  {} {reason}", rows.len()); }
    let boot_report = if boot { read("doctor-trace.json")? } else { Value::Null };
    let return_tracing = if trace_check { boot_report.clone() } else { Value::Null };
    if let Some(drift) = boot_report["jit_mode"]["drift"].as_str() { println!("doctor: {drift}"); }
    if boot_report["jit_mode"]["mismatch"] == true { println!("doctor: certification JIT mode differs after boot; rebuild with matching --jit and startup flags"); }
    if trace_check {
        println!("doctor: return tracing {} ({})", return_tracing["status"].as_str().unwrap_or("not run"),
            return_tracing["reason"].as_str().unwrap_or("boot failed"));
    }
    let report = json!({"format":1,"boot_ok":boot,"baseline_ok":baseline,"command":cmd,
        "static":static_report.ok(),"static_error":static_error,"seal_requested":dynamic,
        "seal_error":dynamic_error,"seal":if seal_ran { read("seal.json")? } else { Value::Null },
        "trace_requested":trace_check,"return_tracing":return_tracing,
        "jit_mode":boot_report["jit_mode"],
        "guarded_ledger_available":!ledger.is_null(),
        "guarded_refusals":refusals});
    let path = app.join(".lowrail/doctor.json");
    std::fs::write(&path, serde_json::to_vec_pretty(&report).unwrap()).map_err(|e| e.to_string())?;
    println!("doctor JSON: {}", path.display());
    if !boot || baseline != Some(true) || static_error.is_some() || dynamic_error.is_some() {
        return Err("doctor incomplete or baseline failed; report retained".into());
    }
    Ok(())
}
