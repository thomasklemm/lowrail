//! `lowrail verify APP`: runs the app's test suite with Lowrail off and on
//! and compares per-test outcomes (docs/PLAN.md section 3.5). Green is only
//! meaningful together with the fast-path hit counts, so those are reported
//! per unit.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

use serde_json::Value;

mod load_controls;

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut app = None;
    let mut bisect = false;
    let mut observe_types = false;
    let mut observe_overhead = false;
    let mut load_controls = None;
    let mut cmd: Vec<String> = vec!["bin/rails".into(), "test".into()];
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--bisect" => bisect = true,
            "--observe-types" => observe_types = true,
            "--observe-overhead" => { observe_types = true; observe_overhead = true; }
            "--load-controls" => load_controls = Some(PathBuf::from(it.next().ok_or("--load-controls needs a JSON file")?)),
            "--" => {
                cmd = it.by_ref().cloned().collect();
                break;
            }
            _ if app.is_none() => app = Some(PathBuf::from(a)),
            _ => return Err(format!("unexpected argument {a}")),
        }
    }
    let app = app.ok_or("usage: lowrail verify APP [--bisect] [--observe-types|--observe-overhead] [--load-controls FILE] [-- TEST COMMAND...]")?;
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
    let pinned = match &load_controls {
        Some(path) => load_controls::load(&app, path)?,
        None => load_controls::Pinned::default(),
    };
    let seed = seed_env(&cmd);
    let mut report = verify(&app, &cmd, &seed, observe_types, pinned)?;
    // Do not retain an exemption if the suite changed either pin.
    if let Some(path) = &load_controls {
        let pinned = load_controls::load(&app, path)?;
        report.known_app_loads = pinned.loads;
        report.known_app_sql = pinned.sql;
    }
    if !report.load_differences().is_empty() {
        report.load_culprit_passes = bisect_load_passes(&app, &cmd, &manifest, &report, &seed)?;
    }
    println!("{}", report.render());
    let mut overhead = None;
    let mut recorder_ok = true;
    if observe_overhead {
        let plain = run_labeled(&app, &cmd, &app.join(".lowrail/verify"), "1-no-recorder", "1", &env_refs(&seed))?;
        let control = Report { off: plain, on: Run {
            tests: report.on.tests.clone(), sql: report.on.sql.clone(),
            sql_other: report.on.sql_other.clone(), processes: report.on.processes,
            loads: report.on.loads.clone(),
            exit_ok: report.on.exit_ok, ..Default::default()
        }, known_app_loads: report.known_app_loads.clone(), known_app_sql: report.known_app_sql.clone(), ..Default::default() };
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
        let culprits = bisect_units(&app, &cmd, &report, &seed)?;
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
    pub ruby_descriptions: BTreeSet<String>,
    /// Process-wide JIT snapshots; never part of equivalence or coverage gates.
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub jit_diagnostics: Vec<Value>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub jit_modes: Vec<Value>,
    #[serde(skip_serializing_if = "BTreeSet::is_empty")]
    pub loads: BTreeSet<String>,
    pub load_snapshot_seconds: f64,
    pub seconds: f64,
    pub exit_ok: bool,
}

#[derive(Debug, Default, serde::Serialize)]
pub struct Report {
    pub off: Run,
    pub on: Run,
    /// Tests whose SQL trace already differs between two LOWRAIL=0 runs
    /// (inlined sequence ids, time, randomness). Their traces cannot gate.
    pub unstable_sql: BTreeSet<String>,
    pub unstable_loads: BTreeSet<String>,
    /// Exact event identities with reviewed off/off evidence for this app pin.
    /// Kept separate from noise observed in the current pair and never erased
    /// from either run's raw census.
    pub known_app_loads: BTreeMap<String, load_controls::Entry>,
    /// Closed, proved whole-trace variants, not blanket per-test exclusions.
    pub known_app_sql: BTreeMap<String, load_controls::SqlEntry>,
    pub load_culprit_passes: Vec<String>,
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
            // A reviewed SQL control may not be broadened by this run's
            // ordinary per-test noise classifier: unknown variants still fail.
            .filter(|(name, _)| self.known_app_sql.contains_key(*name) || !self.unstable_sql.contains(*name))
            .filter_map(|(name, off)| match self.on.sql.get(name) {
                Some(on) if on != off && !self.known_app_sql.get(name).is_some_and(|entry| entry.allows(off) && entry.allows(on)) =>
                    Some(format!("{name}: {} → {} queries", off.1, on.1)),
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

    pub fn load_differences(&self) -> Vec<String> {
        self.off.loads.symmetric_difference(&self.on.loads)
            .filter(|entry| !self.unstable_loads.contains(*entry) && !self.known_app_loads.contains_key(*entry))
            .map(|entry| format!("{}: {entry}", if self.on.loads.contains(entry) { "on only" } else { "off only" }))
            .chain(self.off.loads.union(&self.on.loads).filter(|entry| entry.contains("\terrors\t")).cloned())
            .collect()
    }

    pub fn identical(&self) -> bool {
        !self.off.tests.is_empty()
            && self.differences().is_empty()
            && (!self.sql_gates() || self.sql_differences().is_empty())
            && self.load_differences().is_empty()
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
        let other_unstable_sql = self.unstable_sql.iter().filter(|test| !self.known_app_sql.contains_key(*test)).count();
        if other_unstable_sql > 0 {
            s.push_str(&format!(
                "sql traces: {} tests excluded, their queries differ between two runs of the same mode\n",
                other_unstable_sql
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
        for ruby in self.off.ruby_descriptions.union(&self.on.ruby_descriptions) {
            s.push_str(&format!("\nRuby: {ruby}"));
        }
        for mode in &self.on.jit_modes {
            for field in ["drift", "refusal"] {
                if let Some(reason) = mode[field].as_str() {
                    s.push_str(&format!("\nLowrail JIT/admission: {reason}"));
                }
            }
        }
        if !self.off.loads.is_empty() || !self.on.loads.is_empty() {
            let differences = self.load_differences();
            let other_unstable = self.unstable_loads.iter().filter(|entry| !self.known_app_loads.contains_key(*entry)).count();
            s.push_str(&format!("\nload census: {} differences; {} unstable entries advisory; snapshots off/on {:.4}/{:.4}s",
                differences.len(), other_unstable, self.off.load_snapshot_seconds, self.on.load_snapshot_seconds));
            for finding in differences.iter().take(50) {
                s.push_str(&format!("\n  {finding}"));
            }
            if !self.load_culprit_passes.is_empty() {
                s.push_str(&format!("\nload census culprit passes: {}", self.load_culprit_passes.join(", ")));
            }
        }
        if !self.known_app_loads.is_empty() {
            let observed: Vec<_> = self.known_app_loads.iter()
                .filter(|(identity, _)| self.off.loads.contains(*identity) || self.on.loads.contains(*identity)).collect();
            let differing = observed.iter().filter(|(identity, _)| self.off.loads.contains(*identity) != self.on.loads.contains(*identity)).count();
            s.push_str(&format!("\nknown app nondeterminism: {differing} differing load identities; {} observed; {} pinned controls",
                observed.len(), self.known_app_loads.len()));
            for (identity, entry) in observed {
                s.push_str(&format!("\n  {identity} [off={}, on={}; evidence: {}; origin: {}]",
                    self.off.loads.contains(identity), self.on.loads.contains(identity), entry.evidence, entry.origin));
            }
        }
        if !self.known_app_sql.is_empty() {
            let differing = self.known_app_sql.keys().filter(|test| self.off.sql.get(*test) != self.on.sql.get(*test)).count();
            s.push_str(&format!("\nknown app nondeterminism: SQL; {differing} differing tests; {} pinned controls", self.known_app_sql.len()));
            for (test, entry) in &self.known_app_sql {
                s.push_str(&format!("\n  {test}: {} [off={:?}, on={:?}; origin: {}]",
                    entry.identity, self.off.sql.get(test), self.on.sql.get(test), entry.origin));
                for variant in &entry.variants {
                    s.push_str(&format!("\n    allowed {} / {} queries; evidence: {}", variant.digest, variant.count, variant.evidence));
                }
            }
        }
        let diagnostics = self.off.jit_diagnostics.len() + self.on.jit_diagnostics.len();
        if diagnostics > 0 {
            s.push_str(&format!("\nJIT diagnostics: {diagnostics} process snapshots in last.json (not per-ISeq counters; not a gate)"));
        }
        s
    }
}

/// Both runs (and bisect reruns) use the same test order, so
/// order-dependent work (the first test in a process loads schemas, creates
/// triggers, warms caches) lands in the same test. A command --seed wins;
/// otherwise preserve explicit SEED, TESTOPTS or SPEC_OPTS.
fn seed_env(cmd: &[String]) -> Vec<(String, String)> {
    let command_seed = cmd.iter().enumerate().filter_map(|(i, arg)| {
        if arg == "--seed" { cmd.get(i + 1).map(String::as_str) }
        else { arg.strip_prefix("--seed=") }
    }).last();
    if let Some(seed) = command_seed {
        eprintln!("lowrail verify: command seed {seed} for every run");
        // RSpec parses SPEC_OPTS after ARGV. Retain filters and other caller
        // options, but never let a later environment seed replace this one.
        let options = format!("{} --seed {seed}", std::env::var("SPEC_OPTS").unwrap_or_default());
        return vec![("SEED".into(), seed.into()), ("SPEC_OPTS".into(), options.trim().into())];
    }
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

fn verify(app: &Path, cmd: &[String], seed: &[(String, String)], observe_types: bool,
    pinned: load_controls::Pinned) -> Result<Report, String> {
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
    let mut report = Report { off, on, known_app_loads: pinned.loads, known_app_sql: pinned.sql, ..Default::default() };
    // Only when SQL would fail the gate: a second LOWRAIL=0 run tells
    // run-to-run noise apart from differences Lowrail causes.
    if (report.sql_gates() && !report.sql_differences().is_empty()) || !report.load_differences().is_empty() {
        eprintln!("lowrail verify: SQL/load traces differ; control run with LOWRAIL=0");
        let control = run_labeled(app, cmd, &dir, "0-control", "0", &env)?;
        report.unstable_sql = unstable(&report.off, &control);
        report.unstable_loads = report.off.loads.symmetric_difference(&control.loads).cloned().collect();
        // A test that varies only now and then can agree in two off runs by
        // chance. If differences remain, repeat the on run as well. Agreement
        // across these finite controls is not proof of causality: rare app
        // races need reviewed, pinned off/off evidence (--load-controls).
        if !report.sql_differences().is_empty() || !report.load_differences().is_empty() {
            eprintln!("lowrail verify: SQL/load traces still differ; control run with LOWRAIL=1");
            let on_control = run_labeled(app, cmd, &dir, "1-control", "1", &env)?;
            report.unstable_sql.extend(unstable(&report.on, &on_control));
            report.unstable_loads.extend(report.on.loads.symmetric_difference(&on_control.loads).cloned());
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

/// Isolate activation effects as well as executed fast paths. Passes.install
/// respects LOWRAIL_UNITS, so disabled passes cannot run eager setup code.
fn bisect_load_passes(app: &Path, cmd: &[String], manifest: &Value, report: &Report, seed: &[(String, String)]) -> Result<Vec<String>, String> {
    let mut findings: Vec<_> = report.off.loads.symmetric_difference(&report.on.loads)
        .filter(|entry| !report.unstable_loads.contains(*entry) && !report.known_app_loads.contains_key(*entry)).collect();
    // An empty string disables setup entirely. A nonexistent (negative) ID
    // keeps delivery installed but every source arm falls back: distinguish
    // a loader/setup effect from a particular pass's activation.
    let mut env = env_refs(seed);
    env.push(("LOWRAIL_UNITS", "-1"));
    let setup = run_labeled(app, cmd, &app.join(".lowrail/verify"), "loads-setup", "1", &env)?;
    let mut culprits = Vec::new();
    if findings.iter().any(|entry| report.off.loads.contains(*entry) != setup.loads.contains(*entry)) {
        culprits.push("setup/source delivery (no active units)".into());
        findings.retain(|entry| report.off.loads.contains(*entry) == setup.loads.contains(*entry));
    }
    if findings.is_empty() { return Ok(culprits); }
    let mut groups: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for unit in manifest["units"].as_array().into_iter().flatten() {
        if let (Some(pass), Some(id)) = (unit["pass"].as_str(), unit["id"].as_u64()) {
            groups.entry(pass.to_string()).or_default().push(id.to_string());
        }
    }
    for (index, (pass, ids)) in groups.into_iter().enumerate() {
        let list = ids.join(",");
        let mut env = env_refs(seed);
        env.push(("LOWRAIL_UNITS", &list));
        let on = run_labeled(app, cmd, &app.join(".lowrail/verify"), &format!("loads-pass-{index}"), "1", &env)?;
        if findings.iter().any(|entry| report.off.loads.contains(*entry) != on.loads.contains(*entry)) {
            culprits.push(pass);
        }
    }
    if culprits.is_empty() {
        culprits.push("setup/source delivery or combined passes (no single pass reproduces)".into());
    }
    Ok(culprits)
}

/// Finds the units whose lowering changes outcomes: splits the unit set and
/// reruns the suite with only one half enabled (LOWRAIL_UNITS), recursing
/// into halves that still differ. A set whose halves are each clean is
/// reported whole (the units only fail together).
fn bisect_units(app: &Path, cmd: &[String], report: &Report, seed: &[(String, String)]) -> Result<Vec<Vec<u64>>, String> {
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
        let off = &report.off;
        let r = Report {
            off: Run { tests: off.tests.clone(), sql: off.sql.clone(), sql_other: off.sql_other.clone(), loads: off.loads.clone(), exit_ok: off.exit_ok, ..Default::default() },
            on,
            unstable_sql: report.unstable_sql.clone(),
            known_app_loads: report.known_app_loads.clone(),
            known_app_sql: report.known_app_sql.clone(),
            ..Default::default()
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
                list.push(serde_json::json!({"file": u["file"], "kind": u["kind"], "pass": u["pass"], "evidence": evidence.iter().take(5).collect::<Vec<_>>()}));
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
        if let Some(ruby) = data["ruby"].as_str() {
            run.ruby_descriptions.insert(ruby.to_string());
        }
        if let Some(rubies) = data["ruby_descriptions"].as_array() {
            run.ruby_descriptions.extend(rubies.iter().filter_map(Value::as_str).map(str::to_string));
        }
        if let Some(snapshots) = data["jit_diagnostics"].as_array() {
            run.jit_diagnostics.extend(snapshots.iter().cloned());
        }
        if let Some(modes) = data["jit_modes"].as_array() {
            run.jit_modes.extend(modes.iter().cloned());
        }
        if let Some(stages) = data["verify_loads"]["stages"].as_object() {
            run.load_snapshot_seconds += data["verify_loads"]["snapshot_seconds"].as_f64().unwrap_or(0.0);
            for required in ["first_test", "after_suite"] {
                if !stages.contains_key(required) {
                    run.loads.insert(format!("{required}\terrors\tload snapshot missing"));
                }
            }
            for (stage, categories) in stages {
                run.loads.insert(format!("{stage}\tpresent\t"));
                for (category, entries) in categories.as_object().into_iter().flatten() {
                    for entry in entries.as_array().into_iter().flatten().filter_map(Value::as_str) {
                        run.loads.insert(format!("{stage}\t{category}\t{entry}"));
                    }
                }
            }
        } else if std::env::var("LOWRAIL_VERIFY_LOADS").as_deref() == Ok("1") {
            run.loads.insert("first_test\terrors\tload census missing from outcomes".into());
        }
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
