//! `lowrail verify APP`: runs the app's test suite with Lowrail off and on
//! and compares per-test outcomes (docs/PLAN.md section 3.5). Green is only
//! meaningful together with the fast-path hit counts, so those are reported
//! per unit.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

use serde_json::Value;

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut app = None;
    let mut cmd: Vec<String> = vec!["bin/rails".into(), "test".into()];
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--" => {
                cmd = it.by_ref().cloned().collect();
                break;
            }
            _ if app.is_none() => app = Some(PathBuf::from(a)),
            _ => return Err(format!("unexpected argument {a}")),
        }
    }
    let app = app.ok_or("usage: lowrail verify APP [-- TEST COMMAND...]")?;
    let app = app.canonicalize().map_err(|e| format!("{}: {e}", app.display()))?;
    let report = verify(&app, &cmd)?;
    println!("{}", report.render());
    if report.identical() { Ok(()) } else { Err("outcomes differ".into()) }
}

#[derive(Debug, Default)]
pub struct Run {
    pub tests: BTreeMap<String, (String, String)>,
    pub unit_hits: BTreeMap<String, u64>,
    pub seconds: f64,
    pub exit_ok: bool,
}

#[derive(Debug)]
pub struct Report {
    pub off: Run,
    pub on: Run,
}

impl Report {
    pub fn differences(&self) -> Vec<String> {
        let mut out = Vec::new();
        for (name, off) in &self.off.tests {
            match self.on.tests.get(name) {
                None => out.push(format!("{name}: missing with LOWRAIL=1")),
                Some(on) if on != off => out.push(format!("{name}: {} ({}) → {} ({})", off.0, off.1, on.0, on.1)),
                _ => {}
            }
        }
        for name in self.on.tests.keys().filter(|n| !self.off.tests.contains_key(*n)) {
            out.push(format!("{name}: only with LOWRAIL=1"));
        }
        out
    }

    pub fn identical(&self) -> bool {
        !self.off.tests.is_empty() && self.differences().is_empty() && self.off.exit_ok == self.on.exit_ok
    }

    pub fn render(&self) -> String {
        let count = |r: &Run, k: &str| r.tests.values().filter(|v| v.0 == k).count();
        let mut s = String::new();
        for (label, r) in [("LOWRAIL=0", &self.off), ("LOWRAIL=1", &self.on)] {
            s.push_str(&format!(
                "{label}: {} tests, {} pass, {} fail, {} error, {} skip, {:.1}s\n",
                r.tests.len(),
                count(r, "pass"),
                count(r, "fail"),
                count(r, "error"),
                count(r, "skip"),
                r.seconds
            ));
        }
        let diffs = self.differences();
        if diffs.is_empty() {
            s.push_str("outcomes: identical per test\n");
        } else {
            s.push_str(&format!("outcomes: {} differences\n", diffs.len()));
            for d in diffs.iter().take(50) {
                s.push_str(&format!("  {d}\n"));
            }
        }
        let hits: u64 = self.on.unit_hits.values().sum();
        s.push_str(&format!("fast-path hits: {hits} across {} units", self.on.unit_hits.len()));
        for (u, n) in &self.on.unit_hits {
            s.push_str(&format!("\n  unit {u}: {n}"));
        }
        s
    }
}

pub fn verify(app: &Path, cmd: &[String]) -> Result<Report, String> {
    let dir = app.join(".lowrail/verify");
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let off = run(app, cmd, &dir, "0")?;
    let on = run(app, cmd, &dir, "1")?;
    Ok(Report { off, on })
}

fn run(app: &Path, cmd: &[String], dir: &Path, mode: &str) -> Result<Run, String> {
    let out = dir.join(format!("outcomes-{mode}.json"));
    for entry in std::fs::read_dir(dir).map_err(|e| e.to_string())?.flatten() {
        if entry.file_name().to_string_lossy().starts_with(&format!("outcomes-{mode}.json")) {
            let _ = std::fs::remove_file(entry.path());
        }
    }
    let gem_lib = crate::facts::gem_dir().join("lib");
    let rubyopt = format!(
        "{} -I{} -rlowrail/setup",
        std::env::var("RUBYOPT").unwrap_or_default(),
        gem_lib.display()
    );
    let started = Instant::now();
    let status = Command::new(&cmd[0])
        .args(&cmd[1..])
        .current_dir(app)
        .env("RUBYOPT", rubyopt.trim())
        .env("LOWRAIL", mode)
        .env("LOWRAIL_OUTCOMES", &out)
        .env("LOWRAIL_STATS", "1")
        .status()
        .map_err(|e| format!("running {}: {e}", cmd.join(" ")))?;
    let mut run = Run { seconds: started.elapsed().as_secs_f64(), exit_ok: status.success(), ..Default::default() };
    // Parallel test workers write `outcomes-<mode>.json.<pid>`.
    for entry in std::fs::read_dir(dir).map_err(|e| e.to_string())?.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if !name.starts_with(&format!("outcomes-{mode}.json")) {
            continue;
        }
        let data: Value = serde_json::from_str(&std::fs::read_to_string(entry.path()).map_err(|e| e.to_string())?)
            .map_err(|e| format!("{name}: {e}"))?;
        if let Some(tests) = data["tests"].as_object() {
            for (k, v) in tests {
                let result = v["result"].as_str().unwrap_or("?").to_string();
                let failure = v["failure"].as_str().unwrap_or("").to_string();
                run.tests.insert(k.clone(), (result, failure));
            }
        }
        if let Some(hits) = data["unit_hits"].as_object() {
            for (k, v) in hits {
                *run.unit_hits.entry(k.clone()).or_default() += v.as_u64().unwrap_or(0);
            }
        }
    }
    if run.tests.is_empty() {
        return Err(format!("LOWRAIL={mode}: no outcomes recorded in {}", dir.display()));
    }
    Ok(run)
}
