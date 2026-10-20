//! The measurement protocol lives in bench/, shared with the standalone Ruby tools.

use std::process::Command;

use crate::passes::REGISTRY;

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut forwarded = Vec::new();
    let mut app = None;
    let mut pass = None;
    let mut it = args.iter();
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--pass" => {
                let name = it.next().ok_or("--pass needs a value")?;
                let canonical = if name == "default" {
                    "default"
                } else {
                    REGISTRY.iter().find(|p| p.name == name || p.alias == name)
                        .ok_or_else(|| format!("unknown pass {name}"))?.name
                };
                if pass.replace(canonical).is_some() { return Err("specify --pass once".into()); }
            }
            "--path" | "--out" | "--counter" | "--micro-case" | "--model" => {
                forwarded.push(arg.clone());
                forwarded.push(it.next().ok_or_else(|| format!("{arg} needs a value"))?.clone());
            }
            "--diagnostics" => forwarded.push(arg.clone()),
            _ if !arg.starts_with('-') && app.is_none() => app = Some(arg.clone()),
            _ => return Err(format!("unexpected argument {arg}")),
        }
    }
    let app = app.ok_or("usage: lowrail bench APP --pass NAME [--path /path] [--out NEW_DIR] [--counter callgrind|native] [--micro-case CASE --model MODEL] [--diagnostics]")?;
    let pass = pass.ok_or("bench requires --pass NAME (or default for base-cost layers)")?;
    let script = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("bench/pass.rb");
    let status = Command::new("ruby").arg(script).arg(app).args(["--pass", pass])
        .args(forwarded).status().map_err(|e| format!("benchmark: {e}"))?;
    if status.success() { Ok(()) } else { Err(format!("benchmark rejected ({status}); inspect result.json and private logs")) }
}
