//! `lowrail verify APP`: runs the app's test suite with Lowrail off and on
//! and compares per-test outcomes (docs/PLAN.md section 3.5). Green is only
//! meaningful together with the fast-path hit counts, so those are reported
//! per unit.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

use serde_json::Value;

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut app = None;
    let mut bisect = false;
    let mut observe_types = false;
    let mut observe_overhead = false;
    let mut cmd: Vec<String> = vec!["bin/rails".into(), "test".into()];
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--bisect" => bisect = true,
            "--observe-types" => observe_types = true,
            "--observe-overhead" => { observe_types = true; observe_overhead = true; }
            "--" => {
                cmd = it.by_ref().cloned().collect();
                break;
            }
            _ if app.is_none() => app = Some(PathBuf::from(a)),
            _ => return Err(format!("unexpected argument {a}")),
        }
    }
    let app = app.ok_or("usage: lowrail verify APP [--bisect] [--observe-types|--observe-overhead] [-- TEST COMMAND...]")?;
    let app = app.canonicalize().map_err(|e| format!("{}: {e}", app.display()))?;
    if cmd.is_empty() {
        return Err("test command must not be empty".into());
    }
    // Bind counters to the build selected before execution, not a newer
    // manifest another build might publish while the suite is running.
    let manifest_path = app.join(".lowrail/manifest.json");
    let manifest: Value = if manifest_path.exists() {
        serde_json::from_slice(&std::fs::read(manifest_path).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?
    } else { Value::Null };
    let seed = seed_env();
    let report = verify(&app, &cmd, &seed, observe_types)?;
    println!("{}", report.render());
    let mut overhead = None;
    let mut recorder_ok = true;
    if observe_overhead {
        let plain = run_labeled(&app, &cmd, &app.join(".lowrail/verify"), "1-no-recorder", "1", &env_refs(&seed))?;
        let control = Report { off: plain, on: Run {
            tests: report.on.tests.clone(), sql: report.on.sql.clone(),
            sql_other: report.on.sql_other.clone(), processes: report.on.processes,
            exit_ok: report.on.exit_ok, ..Default::default()
        }, unstable_sql: BTreeSet::new() };
        overhead = Some(serde_json::json!({"recorded_seconds":report.on.seconds,
            "plain_seconds":control.off.seconds,
            "percent":(report.on.seconds / control.off.seconds - 1.0) * 100.0,
            "identical":control.identical(),
            "outcomes_identical":control.differences().is_empty(),
            "sql_differences":control.sql_differences()}));
        println!("recorder overhead (single wall-time pair, not a speed claim): {}", overhead.as_ref().unwrap());
        recorder_ok = control.identical();
    }
    write_last(&app, &cmd, &manifest, &report, overhead)?;
    if !recorder_ok { return Err("recorder control differs".into()); }
    if report.identical() {
        return Ok(());
    }
    if bisect {
        let culprits = bisect_units(&app, &cmd, &report.off, &report.unstable_sql, &seed)?;
        println!("culprit units: {culprits:?}");
        write_denylist(&app, &culprits, &report.differences())?;
    }
    Err("outcomes differ".into())
}

#[derive(Debug, Default, serde::Serialize)]
pub struct Run {
    pub tests: BTreeMap<String, (String, String)>,
    pub unit_hits: BTreeMap<String, u64>,
    /// Guard false: the original code ran. Not a failure, but a unit that only
    /// falls back is a pass that does nothing (often a guard bug).
    pub unit_fallbacks: BTreeMap<String, u64>,
    /// Per-test SQL trace digest and event count (gem/lib/lowrail/sql_trace.rb).
    pub sql: BTreeMap<String, (String, u64)>,
    /// Digest of queries from other threads (advisory: interleaving varies).
    pub sql_other: BTreeMap<String, String>,
    /// Test processes that recorded outcomes (forked workers count).
    pub processes: usize,
    pub seconds: f64,
    pub exit_ok: bool,
}

#[derive(Debug, serde::Serialize)]
pub struct Report {
    pub off: Run,
    pub on: Run,
    /// Tests whose SQL trace already differs between two LOWRAIL=0 runs
    /// (inlined sequence ids, time, randomness). Their traces cannot gate.
    pub unstable_sql: BTreeSet<String>,
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

    /// Tests whose SQL trace differs. Only tests traced in both runs count:
    /// suites without Active Record have no traces.
    pub fn sql_differences(&self) -> Vec<String> {
        self.off
            .sql
            .iter()
            .filter(|(name, _)| !self.unstable_sql.contains(*name))
            .filter_map(|(name, off)| match self.on.sql.get(name) {
                Some(on) if on.0 != off.0 => Some(format!("{name}: {} → {} queries", off.1, on.1)),
                _ => None,
            })
            .collect()
    }

    /// With several test processes, which test runs first in a process (and
    /// so does once-per-process work such as lazy schema or trigger setup)
    /// depends on scheduling, so SQL traces only gate single-process runs.
    pub fn sql_gates(&self) -> bool {
        self.off.processes <= 1 && self.on.processes <= 1
    }

    /// Tests whose queries on other threads differ; advisory only.
    pub fn sql_other_differences(&self) -> Vec<String> {
        self.off
            .sql_other
            .iter()
            .filter(|(name, off)| self.on.sql.contains_key(*name) && self.on.sql_other.get(*name) != Some(off))
            .map(|(name, _)| name.clone())
            .collect()
    }

    pub fn identical(&self) -> bool {
        !self.off.tests.is_empty()
            && self.differences().is_empty()
            && (!self.sql_gates() || self.sql_differences().is_empty())
            && self.off.exit_ok == self.on.exit_ok
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
        let traced = self.off.sql.keys().filter(|k| self.on.sql.contains_key(*k)).count();
        let sql_diffs = self.sql_differences();
        if !self.unstable_sql.is_empty() {
            s.push_str(&format!(
                "sql traces: {} tests excluded, their queries differ between two runs of the same mode\n",
                self.unstable_sql.len()
            ));
        }
        if sql_diffs.is_empty() {
            let queries: u64 = self.off.sql.values().map(|v| v.1).sum();
            s.push_str(&format!("sql traces: identical for {traced} tests ({queries} queries)\n"));
        } else {
            let note = if self.sql_gates() {
                ""
            } else {
                " [advisory: several test processes; rerun with one worker, e.g. PARALLEL_WORKERS=1, to gate on SQL]"
            };
            s.push_str(&format!(
                "sql traces: {} of {traced} tests differ (LOWRAIL_SQL_TRACE=full shows the queries){note}\n",
                sql_diffs.len()
            ));
            for d in sql_diffs.iter().take(50) {
                s.push_str(&format!("  {d}\n"));
            }
        }
        let other = self.sql_other_differences();
        if !other.is_empty() {
            s.push_str(&format!("sql traces on other threads: {} tests differ [advisory: thread interleaving]\n", other.len()));
            for d in other.iter().take(10) {
                s.push_str(&format!("  {d}\n"));
            }
        }
        let hits: u64 = self.on.unit_hits.values().sum();
        s.push_str(&format!("fast-path hits: {hits} across {} units", self.on.unit_hits.len()));
        for (u, n) in &self.on.unit_hits {
            s.push_str(&format!("\n  unit {u}: {n}"));
        }
        let falls: u64 = self.on.unit_fallbacks.values().sum();
        s.push_str(&format!("\nfallbacks: {falls} across {} units", self.on.unit_fallbacks.len()));
        for (u, n) in &self.on.unit_fallbacks {
            let only = if self.on.unit_hits.contains_key(u) { "" } else { " (never took the fast path)" };
            s.push_str(&format!("\n  unit {u}: {n}{only}"));
        }
        s
    }
}

/// Both runs (and bisect reruns) use the same test order, so
/// order-dependent work (the first test in a process loads schemas, creates
/// triggers, warms caches) lands in the same test. An explicit SEED,
/// TESTOPTS or SPEC_OPTS wins.
fn seed_env() -> Vec<(String, String)> {
    if ["SEED", "TESTOPTS", "SPEC_OPTS"].iter().any(|k| std::env::var_os(k).is_some()) {
        return Vec::new();
    }
    let seed = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.subsec_nanos() % 65_536).unwrap_or(1729);
    eprintln!("lowrail verify: test seed {seed} for every run");
    vec![("SEED".into(), seed.to_string()), ("SPEC_OPTS".into(), format!("--seed {seed}"))]
}

fn env_refs(env: &[(String, String)]) -> Vec<(&str, &str)> {
    env.iter().map(|(k, v)| (k.as_str(), v.as_str())).collect()
}

fn verify(app: &Path, cmd: &[String], seed: &[(String, String)], observe_types: bool) -> Result<Report, String> {
    let dir = app.join(".lowrail/verify");
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let env = env_refs(seed);
    let off = run_with(app, cmd, &dir, "0", &env)?;
    let observe_dir = dir.join("observe-on");
    let on = if observe_types {
        if observe_dir.exists() { std::fs::remove_dir_all(&observe_dir).map_err(|e| e.to_string())?; }
        std::fs::create_dir_all(&observe_dir).map_err(|e| e.to_string())?;
        let path = observe_dir.display().to_string();
        let root = app.display().to_string();
        let mut recording = env.clone();
        recording.extend([("LOWRAIL_OBSERVE", path.as_str()), ("LOWRAIL_OBSERVE_ROOT", root.as_str()),
            ("LOWRAIL_OBSERVE_TYPES_ONLY", "1")]);
        let on = run_with(app, cmd, &dir, "1", &recording)?;
        let mut samples = crate::observe::merge(&observe_dir)?;
        samples.command = cmd.to_vec();
        samples.seconds = on.seconds;
        samples.exit_ok = on.exit_ok;
        let out = app.join(".lowrail/observed.json");
        let tmp = out.with_extension("json.tmp");
        std::fs::write(&tmp, serde_json::to_vec(&samples).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?;
        std::fs::rename(tmp, out).map_err(|e| e.to_string())?;
        on
    } else { run_with(app, cmd, &dir, "1", &env)? };
    let mut report = Report { off, on, unstable_sql: BTreeSet::new() };
    // Only when SQL would fail the gate: a second LOWRAIL=0 run tells
    // run-to-run noise apart from differences Lowrail causes.
    if report.sql_gates() && !report.sql_differences().is_empty() {
        eprintln!("lowrail verify: SQL traces differ; control run with LOWRAIL=0");
        let control = run_labeled(app, cmd, &dir, "0-control", "0", &env)?;
        report.unstable_sql = unstable(&report.off, &control);
        // A test that varies only now and then can agree in two off runs by
        // chance. If differences remain, repeat the on run as well: only a
        // difference both on runs agree on, against two agreeing off runs,
        // counts as caused by Lowrail.
        if !report.sql_differences().is_empty() {
            eprintln!("lowrail verify: SQL traces still differ; control run with LOWRAIL=1");
            let on_control = run_labeled(app, cmd, &dir, "1-control", "1", &env)?;
            report.unstable_sql.extend(unstable(&report.on, &on_control));
        }
    }
    Ok(report)
}

fn write_last(app: &Path, cmd: &[String], manifest: &Value, report: &Report, overhead: Option<Value>) -> Result<(), String> {
    let mut passes: BTreeMap<String, Value> = BTreeMap::new();
    for unit in manifest["units"].as_array().into_iter().flatten() {
        let Some(pass) = unit["pass"].as_str() else { continue };
        let id = unit["id"].to_string();
        let entry = passes.entry(pass.into()).or_insert_with(|| serde_json::json!({"hits":0,"fallbacks":0}));
        for (field, counts) in [("hits", &report.on.unit_hits), ("fallbacks", &report.on.unit_fallbacks)] {
            entry[field] = Value::from(entry[field].as_u64().unwrap() + counts.get(&id).copied().unwrap_or(0));
        }
    }
    let identical = report.identical() && overhead.as_ref().is_none_or(|o| o["identical"] == true);
    let result = serde_json::json!({"format":1,"command":cmd,"identical":identical,
        "manifest":manifest,"report":report,"passes":passes,"recorder_overhead":overhead});
    let path = app.join(".lowrail/verify/last.json");
    let tmp = path.with_extension("json.tmp");
    std::fs::write(&tmp, serde_json::to_vec_pretty(&result).unwrap()).map_err(|e| e.to_string())?;
    std::fs::rename(tmp, path).map_err(|e| e.to_string())
}

/// Tests whose own-thread SQL trace differs between two runs of one mode.
fn unstable(a: &Run, b: &Run) -> BTreeSet<String> {
    a.sql.iter().filter(|(name, x)| b.sql.get(*name).map(|y| &y.0) != Some(&x.0)).map(|(name, _)| name.clone()).collect()
}

/// Finds the units whose lowering changes outcomes: splits the unit set and
/// reruns the suite with only one half enabled (LOWRAIL_UNITS), recursing
/// into halves that still differ. A set whose halves are each clean is
/// reported whole (the units only fail together).
fn bisect_units(app: &Path, cmd: &[String], off: &Run, unstable: &BTreeSet<String>, seed: &[(String, String)]) -> Result<Vec<Vec<u64>>, String> {
    let manifest: Value = serde_json::from_str(
        &std::fs::read_to_string(app.join(".lowrail/manifest.json")).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    let ids: Vec<u64> = manifest["units"].as_array().into_iter().flatten().filter_map(|u| u["id"].as_u64()).collect();
    let dir = app.join(".lowrail/verify");
    let mut found = Vec::new();
    let mut runs = 0;
    let mut differs = |set: &[u64]| -> Result<bool, String> {
        runs += 1;
        let list = set.iter().map(|i| i.to_string()).collect::<Vec<_>>().join(",");
        let mut env = env_refs(seed);
        env.push(("LOWRAIL_UNITS", &list));
        let on = run_with(app, cmd, &dir, "1", &env)?;
        let r = Report {
            off: Run { tests: off.tests.clone(), sql: off.sql.clone(), sql_other: off.sql_other.clone(), exit_ok: off.exit_ok, ..Default::default() },
            on,
            unstable_sql: unstable.clone(),
        };
        eprintln!("bisect: units [{list}] → {}", if r.identical() { "identical" } else { "differs" });
        Ok(!r.identical())
    };
    let mut stack = vec![ids];
    while let Some(set) = stack.pop() {
        if set.len() == 1 {
            found.push(set);
            continue;
        }
        let (a, b) = set.split_at(set.len() / 2);
        let (da, db) = (differs(a)?, differs(b)?);
        if da { stack.push(a.to_vec()); }
        if db { stack.push(b.to_vec()); }
        if !da && !db { found.push(set); }
    }
    Ok(found)
}

fn write_denylist(app: &Path, culprits: &[Vec<u64>], evidence: &[String]) -> Result<(), String> {
    let path = app.join(".lowrail/denylist.json");
    let manifest: Value = serde_json::from_str(&std::fs::read_to_string(app.join(".lowrail/manifest.json")).map_err(|e| e.to_string())?)
        .map_err(|e| e.to_string())?;
    let mut list: Vec<Value> = std::fs::read_to_string(&path).ok().and_then(|s| serde_json::from_str(&s).ok()).unwrap_or_default();
    for set in culprits {
        for id in set {
            if let Some(u) = manifest["units"].as_array().into_iter().flatten().find(|u| u["id"].as_u64() == Some(*id)) {
                list.push(serde_json::json!({"file": u["file"], "pass": u["pass"], "evidence": evidence.iter().take(5).collect::<Vec<_>>()}));
            }
        }
    }
    std::fs::write(&path, serde_json::to_string_pretty(&list).unwrap()).map_err(|e| e.to_string())?;
    println!("denylist: {}", path.display());
    Ok(())
}

fn run_with(app: &Path, cmd: &[String], dir: &Path, mode: &str, extra_env: &[(&str, &str)]) -> Result<Run, String> {
    run_labeled(app, cmd, dir, mode, mode, extra_env)
}

/// `label` names the outcome files, `mode` is the LOWRAIL value.
fn run_labeled(app: &Path, cmd: &[String], dir: &Path, label: &str, mode: &str, extra_env: &[(&str, &str)]) -> Result<Run, String> {
    let out = dir.join(format!("outcomes-{label}.json"));
    for entry in std::fs::read_dir(dir).map_err(|e| e.to_string())?.flatten() {
        if entry.file_name().to_string_lossy().starts_with(&format!("outcomes-{label}.json")) {
            let _ = std::fs::remove_file(entry.path());
        }
    }
    let gem_lib = crate::facts::gem_dir().join("lib");
    let mut rubyopt = format!(
        "{} -I{} -rlowrail/setup",
        std::env::var("RUBYOPT").unwrap_or_default(),
        gem_lib.display()
    );
    if extra_env.iter().any(|(k, _)| *k == "LOWRAIL_OBSERVE") {
        rubyopt.push_str(" -rlowrail/observe");
    }
    let started = Instant::now();
    let status = Command::new(&cmd[0])
        .args(&cmd[1..])
        .current_dir(app)
        .env("RUBYOPT", rubyopt.trim())
        .env("LOWRAIL", mode)
        .env("LOWRAIL_SHADOW", "strict")
        .env("LOWRAIL_OUTCOMES", &out)
        .env("LOWRAIL_STATS", "") // counts on; hits come via LOWRAIL_OUTCOMES, no extra stats file
        .env_remove("LOWRAIL_OBSERVE")
        .envs(extra_env.iter().copied())
        .status()
        .map_err(|e| format!("running {}: {e}", cmd.join(" ")))?;
    let mut run = Run { seconds: started.elapsed().as_secs_f64(), exit_ok: status.success(), ..Default::default() };
    // Parallel test workers write `outcomes-<mode>.json.<pid>`. Minitest
    // also writes a merged report: do not count its workers twice.
    for entry in std::fs::read_dir(dir).map_err(|e| e.to_string())?.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if !name.starts_with(&format!("outcomes-{label}.json")) {
            continue;
        }
        if out.is_file() && entry.path() != out {
            continue;
        }
        let data: Value = serde_json::from_str(&std::fs::read_to_string(entry.path()).map_err(|e| e.to_string())?)
            .map_err(|e| format!("{name}: {e}"))?;
        run.processes += match data["processes"].as_array() {
            Some(list) => list.len(),
            None => usize::from(data["tests"].as_object().is_some_and(|t| !t.is_empty())),
        };
        if let Some(tests) = data["tests"].as_object() {
            for (k, v) in tests {
                let result = v["result"].as_str().unwrap_or("?").to_string();
                let failure = v["failure"].as_str().unwrap_or("").to_string();
                run.tests.insert(k.clone(), (result, failure));
            }
        }
        if let Some(sql) = data["sql"].as_object() {
            for (k, v) in sql {
                let digest = v["digest"].as_str().unwrap_or("").to_string();
                run.sql.insert(k.clone(), (digest, v["n"].as_u64().unwrap_or(0)));
                if let Some(o) = v["other_digest"].as_str() {
                    run.sql_other.insert(k.clone(), o.to_string());
                }
            }
        }
        if let Some(hits) = data["unit_hits"].as_object() {
            for (k, v) in hits {
                *run.unit_hits.entry(k.clone()).or_default() += v.as_u64().unwrap_or(0);
            }
        }
        if let Some(falls) = data["unit_fallbacks"].as_object() {
            for (k, v) in falls {
                *run.unit_fallbacks.entry(k.clone()).or_default() += v.as_u64().unwrap_or(0);
            }
        }
    }
    if run.tests.is_empty() {
        return Err(format!("LOWRAIL={mode}: no outcomes recorded in {}", dir.display()));
    }
    Ok(run)
}
