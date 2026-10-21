//! Declared, pinned RNG companions. Never reuse unseeded SQL exemptions.
use std::collections::BTreeSet;
use std::path::Path;

use super::{Report, Run, env_refs, load_controls, run_labeled};

#[derive(Debug, serde::Serialize)]
pub struct Pair {
    pub seed: u64,
    pub off: Run,
    pub on: Run,
    pub differences: Vec<String>,
}

#[derive(Debug, Default, serde::Serialize)]
pub struct Companions {
    pub rng_sources: Vec<load_controls::Rng>,
    pub pairs: Vec<Pair>,
    pub inactive_reason: Option<String>,
    pub unseeded_identical: bool,
    pub unseeded_sql_differences: Vec<String>,
    pub verified_sql: BTreeSet<String>,
}

impl Companions {
    pub fn passed(&self) -> bool {
        self.inactive_reason.is_none() && self.pairs.len() == 2
            && self.pairs.iter().all(|pair| pair.differences.is_empty())
    }

    pub fn render(&self) -> String {
        let mut text = String::from("\nRNG companions (whole-suite outcomes/SQL, no SQL exclusions):");
        text.push_str(&format!("\n  unseeded gate before companion classification: {}; {} rejecting SQL differences",
            if self.unseeded_identical { "passed" } else { "rejected" }, self.unseeded_sql_differences.len()));
        if let Some(reason) = &self.inactive_reason {
            text.push_str(&format!(" inactive: {reason}"));
        }
        for rng in &self.rng_sources {
            text.push_str(&format!("\n  {}: {}; evidence: {}", rng.name, rng.origin, rng.evidence));
        }
        for pair in &self.pairs {
            text.push_str(&format!("\n  seed {}: {} tests, {} queries; {} differences; hits/fallbacks {}/{}",
                pair.seed, pair.off.tests.len(), pair.off.sql.values().map(|v| v.1).sum::<u64>(), pair.differences.len(),
                pair.on.unit_hits.values().sum::<u64>(), pair.on.unit_fallbacks.values().sum::<u64>()));
            for difference in &pair.differences { text.push_str(&format!("\n    {difference}")); }
        }
        if self.passed() {
            text.push_str(&format!("\nRNG-dependent, companion-verified: {} unseeded SQL differences (raw traces retained)", self.verified_sql.len()));
            for test in &self.verified_sql { text.push_str(&format!("\n  {test}")); }
        }
        text
    }
}

pub fn run(app: &Path, cmd: &[String], order_env: &[(String, String)], seeds: &[u64],
    rng_sources: Vec<load_controls::Rng>, primary: &Report) -> Result<Companions, String> {
    let mut result = Companions { rng_sources, unseeded_identical: primary.identical(),
        unseeded_sql_differences: primary.sql_differences(), ..Default::default() };
    if result.rng_sources.is_empty() {
        result.inactive_reason = Some("missing pinned RNG declaration (or app/lock pin mismatch)".into());
        return Ok(result);
    }
    let sources = result.rng_sources.iter().map(|r| r.name.as_str()).collect::<Vec<_>>().join(",");
    for seed in seeds {
        eprintln!("lowrail verify: declared RNG companion seed {seed}, LOWRAIL=0 then 1");
        let mut env = order_env.to_vec();
        env.extend([("LOWRAIL_COMPANION_SEED".into(), seed.to_string()),
            ("LOWRAIL_COMPANION_RNGS".into(), sources.clone())]);
        let dir = app.join(".lowrail/verify");
        let off = run_labeled(app, cmd, &dir, &format!("companion-{seed}-0"), "0", &env_refs(&env))?;
        let on = run_labeled(app, cmd, &dir, &format!("companion-{seed}-1"), "1", &env_refs(&env))?;
        let control = Report { off, on, known_app_loads: primary.known_app_loads.clone(),
            unstable_loads: primary.unstable_loads.clone(), ..Default::default() };
        let mut differences = control.differences();
        if control.off.tests.is_empty() || control.off.tests.keys().ne(primary.off.tests.keys())
            || control.on.tests.keys().ne(primary.on.tests.keys()) {
            differences.push("companion did not execute the same whole suite".into());
        }
        if !control.off.exit_ok || !control.on.exit_ok {
            differences.push("companion test command failed".into());
        }
        // Map equality also rejects missing traces, multiple-worker noise and
        // unknown variants. Other-thread digest advisories remain separate.
        if control.off.sql != control.on.sql {
            differences.push("companion SQL differs (no SQL exclusions apply)".into());
            differences.extend(control.sql_differences());
        }
        if control.off.sql.keys().ne(primary.off.sql.keys()) || control.on.sql.keys().ne(primary.on.sql.keys()) {
            differences.push("companion did not trace SQL for the same whole suite".into());
        }
        differences.extend(control.load_differences());
        for (label, arm) in [("off", &control.off), ("on", &control.on)] {
            let mut seeded_tests = BTreeSet::new();
            let attested = !arm.companion_rng.is_empty() && arm.companion_rng.iter().all(|data| {
                seeded_tests.extend(data["tests"].as_array().into_iter().flatten().filter_map(|v| v.as_str()).map(str::to_string));
                data["seed"].as_u64() == Some(*seed) && data["sources"].as_str() == Some(&sources)
            });
            if !attested || seeded_tests.iter().ne(arm.tests.keys()) {
                differences.push(format!("{label}: missing per-example RNG seeding attestation"));
            }
        }
        result.pairs.push(Pair { seed: *seed, off: control.off, on: control.on, differences });
    }
    if result.passed() && primary.differences().is_empty() {
        result.verified_sql = primary.off.sql.iter()
            .filter(|(test, off)| primary.on.sql.get(*test).is_some_and(|on| on != *off))
            .map(|(test, _)| test.clone()).collect();
    }
    Ok(result)
}
