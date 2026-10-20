//! The measurement protocol lives in bench/, shared with the standalone Ruby tools.

use std::process::Command;

use crate::passes::{Selection, REGISTRY};

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut forwarded = Vec::new();
    let mut app = None;
    let mut pass = None;
    let mut passes = None;
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
            "--passes" => {
                let list = it.next().ok_or("--passes needs a value")?;
                let selection = Selection::parse(list)?;
                let names = selection.iter().map(|p| p.name).collect::<Vec<_>>().join(",");
                if names.is_empty() { return Err("bench pass set must not be empty".into()); }
                if passes.replace(names).is_some() { return Err("specify --passes once".into()); }
            }
            "--path" | "--out" | "--counter" | "--micro-case" | "--model" | "--default-build" | "--budgets" | "--speculate" => {
                forwarded.push(arg.clone());
                forwarded.push(it.next().ok_or_else(|| format!("{arg} needs a value"))?.clone());
            }
            "--diagnostics" | "--measure-budgets" => forwarded.push(arg.clone()),
            _ if !arg.starts_with('-') && app.is_none() => app = Some(arg.clone()),
            _ => return Err(format!("unexpected argument {arg}")),
        }
    }
    let app = app.ok_or("usage: lowrail bench APP (--pass NAME | --passes SET --default-build DIR) [--budgets JSON | --measure-budgets] [--path /path] [--out NEW_DIR]")?;
    match (pass, passes) {
        (Some(name), None) => forwarded.extend(["--pass".into(), name.into()]),
        (None, Some(names)) => {
            forwarded.extend(["--passes".into(), names, "--default-passes".into(),
                Selection::default().iter().map(|p| p.name).collect::<Vec<_>>().join(",")]);
        }
        _ => return Err("bench requires exactly one of --pass NAME or --passes SET".into()),
    }
    let script = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("bench/pass.rb");
    let status = Command::new("ruby").arg(script).arg(app)
        .args(forwarded).status().map_err(|e| format!("benchmark: {e}"))?;
    if status.success() { Ok(()) } else { Err(format!("benchmark rejected ({status}); inspect result.json and private logs")) }
}
