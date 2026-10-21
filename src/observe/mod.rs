//! `lowrail observe APP [-- TEST COMMAND]`: runs the app's test suite with
//! the recorder (`gem/lib/lowrail/observe.rb`, through RUBYOPT, LOWRAIL=0),
//! merges the per-process files into `APP/.lowrail/observed.json`
//! (docs/FORMATS.md) and compares what the run defined after boot with the
//! boot facts (`APP/.lowrail/facts.json`, materialized).

use crate::facts::generated::{Form, Generated, is_template};
use crate::facts::schema::{Facts, GeneratedScript, GeneratedStats, Method, split_location};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

const USAGE: &str = "usage: lowrail observe APP [--samples N] [--method MOD#METH]... [--no-types]
                       [--facts PATH] [--overhead] [--no-run] [-- TEST COMMAND...]
  runs APP's tests (default: bin/rails test) with the observe recorder,
  writes APP/.lowrail/observed.json and compares it with the boot facts;
  --overhead first runs the same command without the recorder and reports
  both wall times; --no-run re-merges the files of the last run";

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Observed {
    pub format: u32,
    pub app_root: String,
    pub ruby_description: String,
    pub command: Vec<String>,
    pub seconds: f64,
    pub exit_ok: bool,
    pub processes: Vec<u32>,
    pub modules_at_boot: usize,
    pub modules_after_boot: usize,
    pub defined_after_boot: Vec<ObservedMethod>,
    pub generated_scripts: Vec<GeneratedScript>,
    pub generated_stats: GeneratedStats,
    pub samples_per_method: usize,
    pub hooked_methods: usize,
    pub types: Vec<MethodTypes>,
    pub timings: BTreeMap<String, BTreeMap<String, f64>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub comparison: Option<Comparison>,
}

/// One process's file (`observe/observed-<pid>.json`).
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
struct Partial {
    pid: u32,
    app_root: String,
    ruby_description: String,
    modules_at_boot: usize,
    modules_after_boot: usize,
    defined_after_boot: Vec<ObservedMethod>,
    generated_scripts: Vec<GeneratedScript>,
    generated_stats: GeneratedStats,
    samples_per_method: usize,
    hooked_methods: usize,
    types: Vec<MethodTypes>,
    timings: BTreeMap<String, f64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct ObservedMethod {
    pub module: String,
    pub name: String,
    pub singleton: bool,
    pub visibility: String,
    pub owner: String,
    pub source_location: Option<String>,
    pub parameters: Vec<Vec<String>>,
    pub iseq_kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub original_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub script: Option<String>,
    /// The module itself was created after boot.
    #[serde(skip_serializing_if = "std::ops::Not::not")]
    pub module_new: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct MethodTypes {
    pub module: String,
    pub name: String,
    pub singleton: bool,
    pub source_location: Option<String>,
    /// Sampled calls (the hook disables itself after `samples_per_method`
    /// returns: `saturated`).
    pub calls: u64,
    pub saturated: bool,
    #[serde(rename = "self")]
    pub self_: BTreeMap<String, u64>,
    pub args: BTreeMap<String, BTreeMap<String, u64>>,
    /// Receiver ivars present at sampled returns; absence is not nil.
    pub ivars: BTreeMap<String, BTreeMap<String, u64>>,
    pub returns: BTreeMap<String, u64>,
}

/// Observed definitions against the boot facts.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Comparison {
    pub facts: String,
    pub defined_after_boot: usize,
    /// Also present in facts.json (materialize covered it).
    pub in_facts: usize,
    /// Same generated script (content digest), or the same name and
    /// generated `def` text, as a method in the facts: e.g. CodeGenerator's
    /// anonymous method caches (shared across models, batched in a
    /// different order per run), whose copies the facts list on each
    /// model's GeneratedAttributeMethods.
    pub in_facts_by_script: usize,
    /// Compiled template methods whose template the facts compiled too
    /// (method names embed an object id, so they never match by name).
    pub templates_compiled_in_facts: usize,
    pub not_in_facts: usize,
    /// not_in_facts by where the body comes from.
    pub by_source: BTreeMap<String, usize>,
    /// not_in_facts by module (all of them).
    pub by_module: BTreeMap<String, usize>,
    pub methods: Vec<NewMethod>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct NewMethod {
    pub module: String,
    pub name: String,
    pub singleton: bool,
    pub source: String,
    pub source_location: Option<String>,
}

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut app = None;
    let mut cmd: Vec<String> = vec!["bin/rails".into(), "test".into()];
    let mut samples = None;
    let mut methods = Vec::new();
    let mut types = true;
    let mut facts_path = None;
    let mut overhead = false;
    let mut no_run = false;
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--samples" => samples = Some(it.next().ok_or(USAGE)?.clone()),
            "--method" => methods.push(it.next().ok_or(USAGE)?.clone()),
            "--no-types" => types = false,
            "--facts" => facts_path = Some(PathBuf::from(it.next().ok_or(USAGE)?)),
            "--overhead" => overhead = true,
            "--no-run" => no_run = true,
            "--" => {
                cmd = it.by_ref().cloned().collect();
                break;
            }
            s if !s.starts_with('-') && app.is_none() => app = Some(PathBuf::from(s)),
            _ => return Err(USAGE.into()),
        }
    }
    if cmd.is_empty() {
        return Err(USAGE.into());
    }
    let app = app.ok_or(USAGE)?;
    let app = app
        .canonicalize()
        .map_err(|e| format!("{}: {e}", app.display()))?;
    let lowrail_dir = app.join(".lowrail");
    let dir = lowrail_dir.join("observe");
    std::fs::create_dir_all(&dir).map_err(|e| format!("{}: {e}", dir.display()))?;

    if no_run {
        let mut observed = merge(&dir)?;
        let facts_path = facts_path.unwrap_or_else(|| lowrail_dir.join("facts.json"));
        if facts_path.exists() {
            let facts = crate::facts::load(&facts_path)?;
            observed.comparison = Some(compare(&observed, &facts, &facts_path, Some(&lowrail_dir.join("generated")))?);
        }
        let out = lowrail_dir.join("observed.json");
        if let Ok(prev) = std::fs::read(&out)
            && let Ok(prev) = serde_json::from_slice::<Observed>(&prev)
        {
            (observed.command, observed.seconds, observed.exit_ok) = (prev.command, prev.seconds, prev.exit_ok);
        }
        let json = serde_json::to_vec(&observed).map_err(|e| e.to_string())?;
        std::fs::write(&out, json).map_err(|e| format!("{}: {e}", out.display()))?;
        print!("{}", summary(&observed, &out, None));
        return Ok(());
    }
    let plain = if overhead {
        Some(run(&app, &cmd, &[], false)?.0)
    } else {
        None
    };
    for entry in std::fs::read_dir(&dir).map_err(|e| e.to_string())?.flatten() {
        if entry.file_name().to_string_lossy().starts_with("observed-") {
            let _ = std::fs::remove_file(entry.path());
        }
    }
    let mut env: Vec<(&str, String)> = vec![
        ("LOWRAIL_OBSERVE", dir.display().to_string()),
        ("LOWRAIL_OBSERVE_ROOT", app.display().to_string()),
    ];
    if let Some(n) = &samples {
        env.push(("LOWRAIL_OBSERVE_SAMPLES", n.clone()));
    }
    if !methods.is_empty() {
        env.push(("LOWRAIL_OBSERVE_METHODS", methods.join(",")));
    }
    if !types {
        env.push(("LOWRAIL_OBSERVE_TYPES", "0".into()));
    }
    let (seconds, exit_ok) = run(&app, &cmd, &env, true)?;
    let mut observed = merge(&dir)?;
    observed.command = cmd.clone();
    observed.seconds = seconds;
    observed.exit_ok = exit_ok;
    let facts_path = facts_path.unwrap_or_else(|| lowrail_dir.join("facts.json"));
    if facts_path.exists() {
        let facts = crate::facts::load(&facts_path)?;
        observed.comparison = Some(compare(&observed, &facts, &facts_path, Some(&lowrail_dir.join("generated")))?);
    }
    let out = lowrail_dir.join("observed.json");
    let json = serde_json::to_vec(&observed).map_err(|e| e.to_string())?;
    std::fs::write(&out, json).map_err(|e| format!("{}: {e}", out.display()))?;
    print!("{}", summary(&observed, &out, plain));
    if !exit_ok {
        eprintln!("note: the test command exited unsuccessfully");
    }
    Ok(())
}

fn run(app: &Path, cmd: &[String], env: &[(&str, String)], recorder: bool) -> Result<(f64, bool), String> {
    let mut c = Command::new(&cmd[0]);
    c.args(&cmd[1..]).current_dir(app).env("LOWRAIL", "0");
    if std::env::var_os("PARALLEL_WORKERS").is_none() {
        c.env("PARALLEL_WORKERS", "1");
    }
    if recorder {
        let gem_lib = crate::facts::gem_dir().join("lib");
        let rubyopt = format!(
            "{} -I{} -rlowrail/observe",
            std::env::var("RUBYOPT").unwrap_or_default(),
            gem_lib.display()
        );
        c.env("RUBYOPT", rubyopt.trim());
        c.envs(env.iter().map(|(k, v)| (*k, v.as_str())));
    }
    let started = Instant::now();
    let status = c
        .status()
        .map_err(|e| format!("running {}: {e}", cmd.join(" ")))?;
    Ok((started.elapsed().as_secs_f64(), status.success()))
}

/// Merges every `observed-<pid>.json` in `dir`.
pub fn merge(dir: &Path) -> Result<Observed, String> {
    let mut parts = Vec::new();
    for entry in std::fs::read_dir(dir).map_err(|e| e.to_string())?.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if !(name.starts_with("observed-") && name.ends_with(".json")) {
            continue;
        }
        let bytes = std::fs::read(entry.path()).map_err(|e| format!("{name}: {e}"))?;
        let p: Partial = serde_json::from_slice(&bytes).map_err(|e| format!("{name}: {e}"))?;
        parts.push(p);
    }
    if parts.is_empty() {
        return Err(format!(
            "no observed-*.json in {} (did the command boot Rails?)",
            dir.display()
        ));
    }
    parts.sort_by_key(|p| p.pid);
    Ok(merge_parts(parts))
}

fn merge_parts(parts: Vec<Partial>) -> Observed {
    let mut o = Observed {
        format: 1,
        ..Default::default()
    };
    let mut defined: BTreeMap<(String, bool, String), ObservedMethod> = BTreeMap::new();
    let mut scripts: BTreeMap<(String, String, i64, String, String), GeneratedScript> = BTreeMap::new();
    let mut types: BTreeMap<(String, bool, String), MethodTypes> = BTreeMap::new();
    for p in parts {
        o.processes.push(p.pid);
        o.app_root = p.app_root;
        o.ruby_description = p.ruby_description;
        o.modules_at_boot = o.modules_at_boot.max(p.modules_at_boot);
        o.modules_after_boot = o.modules_after_boot.max(p.modules_after_boot);
        o.samples_per_method = p.samples_per_method;
        o.hooked_methods = o.hooked_methods.max(p.hooked_methods);
        o.generated_stats.compilations += p.generated_stats.compilations;
        o.generated_stats.bytes += p.generated_stats.bytes;
        o.generated_stats.hook_seconds += p.generated_stats.hook_seconds;
        if let Some(reason) = p.generated_stats.linking_decline {
            o.generated_stats.linking_decline.get_or_insert(reason);
        }
        o.timings.insert(p.pid.to_string(), p.timings);
        for m in p.defined_after_boot {
            defined
                .entry((m.module.clone(), m.singleton, m.name.clone()))
                .or_insert(m);
        }
        for s in p.generated_scripts {
            let key = (
                s.sha256.clone(),
                s.path.clone(),
                s.lineno,
                s.module.clone().unwrap_or_default(),
                s.caller.clone().unwrap_or_default(),
            );
            match scripts.get_mut(&key) {
                Some(e) => e.count += s.count,
                None => {
                    scripts.insert(key, s);
                }
            }
        }
        for t in p.types {
            let e = types
                .entry((t.module.clone(), t.singleton, t.name.clone()))
                .or_insert_with(|| MethodTypes {
                    calls: 0,
                    ..t.clone()
                });
            if e.calls > 0 {
                add_counts(&mut e.self_, &t.self_);
                add_counts(&mut e.returns, &t.returns);
                for (arg, c) in &t.args {
                    add_counts(e.args.entry(arg.clone()).or_default(), c);
                }
                for (ivar, c) in &t.ivars {
                    add_counts(e.ivars.entry(ivar.clone()).or_default(), c);
                }
            }
            e.calls += t.calls;
            e.saturated |= t.saturated;
        }
    }
    o.defined_after_boot = defined.into_values().collect();
    o.generated_scripts = scripts.into_values().collect();
    o.generated_stats.scripts = o.generated_scripts.len();
    o.types = types.into_values().collect();
    o
}

fn add_counts(into: &mut BTreeMap<String, u64>, from: &BTreeMap<String, u64>) {
    for (k, v) in from {
        *into.entry(k.clone()).or_default() += v;
    }
}

/// What the run defined after boot that the (materialized) boot facts do not
/// have.
/// `observed_generated` holds the run's generated sources (for matching
/// generated defs by text); the facts' are next to `facts_path`.
pub fn compare(o: &Observed, facts: &Facts, facts_path: &Path, observed_generated: Option<&Path>) -> Result<Comparison, String> {
    // Each source is parsed under the runtime that produced its capture.
    let facts_parser = crate::parser::Parser::for_runtime(&facts.ruby_description)?;
    let observed_parser = crate::parser::Parser::for_runtime(&o.ruby_description)?;
    let mut known: HashSet<(&str, bool, &str)> = HashSet::new();
    for m in &facts.modules {
        for x in &m.methods {
            known.insert((m.name.as_str(), x.singleton, x.name.as_str()));
        }
    }
    let facts_scripts: HashSet<&str> = facts
        .modules
        .iter()
        .flat_map(|m| &m.methods)
        .filter_map(|x| x.script.as_deref())
        .collect();
    let compiled: HashSet<&str> = facts
        .compiled_templates
        .iter()
        .map(|t| t.identifier.as_str())
        .collect();
    let scripts: HashMap<&str, &GeneratedScript> = o
        .generated_scripts
        .iter()
        .map(|s| (s.sha256.as_str(), s))
        .collect();
    let root = PathBuf::from(&o.app_root);
    let gems: Vec<(&str, &str)> = facts
        .gems
        .iter()
        .filter(|g| !g.path.is_empty())
        .map(|g| (g.path.as_str(), g.name.as_str()))
        .collect();
    let mut c = Comparison {
        facts: facts_path.display().to_string(),
        defined_after_boot: o.defined_after_boot.len(),
        ..Default::default()
    };
    let mut facts_defs: Option<HashSet<(String, String)>> = None;
    let observed_facts = Facts {
        ruby_description: o.ruby_description.clone(),
        generated_scripts: o.generated_scripts.clone(),
        ..Default::default()
    };
    let mut observed_gen = observed_generated.map(|d| Generated::new(&observed_facts, d, &observed_parser));
    for m in &o.defined_after_boot {
        if known.contains(&(m.module.as_str(), m.singleton, m.name.as_str())) {
            c.in_facts += 1;
            continue;
        }
        if m.script.as_deref().is_some_and(|s| facts_scripts.contains(s)) {
            c.in_facts_by_script += 1;
            continue;
        }
        if m.script.is_some()
            && let Some(g) = observed_gen.as_mut()
        {
            let defs = facts_defs.get_or_insert_with(|| generated_defs(facts, facts_path, &facts_parser));
            let method = Method {
                name: m.name.clone(),
                source_location: m.source_location.clone(),
                original_name: m.original_name.clone(),
                script: m.script.clone(),
                ..Default::default()
            };
            if let Some(d) = g.link(&method)
                && d.form == Form::Def
                && defs.contains(&(method.def_name().to_string(), d.source))
            {
                c.in_facts_by_script += 1;
                continue;
            }
        }
        let script = m.script.as_deref().and_then(|s| scripts.get(s).copied());
        if let Some(s) = script
            && is_template(s)
            && compiled.contains(s.path.as_str())
        {
            c.templates_compiled_in_facts += 1;
            continue;
        }
        let source = source_category(m, script, &root, &gems);
        *c.by_source.entry(source.clone()).or_default() += 1;
        *c.by_module.entry(m.module.clone()).or_default() += 1;
        c.not_in_facts += 1;
        c.methods.push(NewMethod {
            module: m.module.clone(),
            name: m.name.clone(),
            singleton: m.singleton,
            source,
            source_location: m.source_location.clone(),
        });
    }
    Ok(c)
}

/// (def name, def text) of every facts method with a generated body.
fn generated_defs(facts: &Facts, facts_path: &Path, parser: &crate::parser::Parser) -> HashSet<(String, String)> {
    let mut g = Generated::new(facts, crate::facts::generated_dir(facts_path), parser);
    let mut out = HashSet::new();
    for m in facts.modules.iter().flat_map(|m| &m.methods) {
        if m.script.is_none() {
            continue;
        }
        if let Some(d) = g.link(m)
            && d.form == Form::Def
        {
            out.insert((m.def_name().to_string(), d.source));
        }
    }
    out
}

fn source_category(
    m: &ObservedMethod,
    script: Option<&GeneratedScript>,
    root: &Path,
    gems: &[(&str, &str)],
) -> String {
    if let Some(s) = script {
        if is_template(s) {
            return "template".into();
        }
        let site = s.caller_label.as_deref().unwrap_or("?");
        return format!("generated ({site})");
    }
    let Some((path, _)) = m.source_location.as_deref().and_then(split_location) else {
        return format!("no source ({})", m.iseq_kind);
    };
    let p = Path::new(path);
    if p.starts_with(root.join("test")) || p.starts_with(root.join("spec")) {
        return "app test code".into();
    }
    if p.starts_with(root) && !p.starts_with(root.join("vendor")) {
        return "app".into();
    }
    if let Some((_, name)) = gems
        .iter()
        .filter(|(gp, _)| p.starts_with(gp))
        .max_by_key(|(gp, _)| gp.len())
    {
        return format!("gem {name}");
    }
    if path.starts_with('(') {
        return "eval".into();
    }
    "ruby stdlib/other".into()
}

pub fn summary(o: &Observed, path: &Path, plain_seconds: Option<f64>) -> String {
    use std::fmt::Write;
    let mut s = String::new();
    let w = &mut s;
    let _ = writeln!(w, "observed: {}", path.display());
    let _ = writeln!(
        w,
        "command: {} ({:.1}s{}, {} process{})",
        o.command.join(" "),
        o.seconds,
        plain_seconds
            .map(|p| format!(" vs {p:.1}s without recorder, {:+.0}%", (o.seconds / p - 1.0) * 100.0))
            .unwrap_or_default(),
        o.processes.len(),
        if o.processes.len() == 1 { "" } else { "es" }
    );
    let _ = writeln!(
        w,
        "modules: {} at boot, {} created after boot; methods defined after boot: {}",
        o.modules_at_boot,
        o.modules_after_boot,
        o.defined_after_boot.len()
    );
    let after_boot: Vec<_> = o.generated_scripts.iter().filter(|s| s.phase == "test").collect();
    let _ = writeln!(
        w,
        "generated scripts: {} ({} after boot, {:.1} KB after boot)",
        o.generated_scripts.len(),
        after_boot.len(),
        after_boot.iter().map(|s| s.bytes).sum::<usize>() as f64 / 1e3
    );
    let saturated = o.types.iter().filter(|t| t.saturated).count();
    let _ = writeln!(
        w,
        "types: {} methods hooked, {} called ({} saturated at {} samples)",
        o.hooked_methods,
        o.types.len(),
        saturated,
        o.samples_per_method
    );
    let poly = o.types.iter().filter(|t| t.returns.len() > 1).count();
    let _ = writeln!(w, "  polymorphic returns: {poly}");
    if let Some(c) = &o.comparison {
        let _ = writeln!(
            w,
            "vs facts {}: {} in facts, {} same generated script, {} template methods of templates compiled at boot, {} not in facts",
            c.facts, c.in_facts, c.in_facts_by_script, c.templates_compiled_in_facts, c.not_in_facts
        );
        let mut by: Vec<_> = c.by_source.iter().collect();
        by.sort_by(|a, b| b.1.cmp(a.1).then(a.0.cmp(b.0)));
        for (k, v) in by.iter().take(15) {
            let _ = writeln!(w, "  {v:>6}  {k}");
        }
        let mut mods: Vec<_> = c.by_module.iter().collect();
        mods.sort_by(|a, b| b.1.cmp(a.1).then(a.0.cmp(b.0)));
        let top: Vec<String> = mods.iter().take(12).map(|(m, n)| format!("{m} {n}")).collect();
        let _ = writeln!(w, "  top modules: {}", top.join(", "));
        // App methods by name; template methods by template file (each
        // compilation has its own method name).
        let mut app: BTreeMap<String, usize> = BTreeMap::new();
        for m in &c.methods {
            let key = match m.source.as_str() {
                "app" => format!("{}{}{}", m.module, if m.singleton { "." } else { "#" }, m.name),
                "template" => format!(
                    "template {} in {}",
                    m.source_location
                        .as_deref()
                        .and_then(split_location)
                        .map_or("?", |(p, _)| p),
                    m.module
                ),
                _ => continue,
            };
            *app.entry(key).or_default() += 1;
        }
        if !app.is_empty() {
            let _ = writeln!(w, "  app methods and templates not in facts: {}", app.len());
            for (k, n) in app.iter().take(20) {
                let _ = writeln!(w, "    {k}{}", if *n > 1 { format!(" ({n} methods)") } else { String::new() });
            }
        }
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::facts::schema::{CompiledTemplate, Gem, Module};

    fn om(module: &str, name: &str, loc: Option<&str>, script: Option<&str>) -> ObservedMethod {
        ObservedMethod {
            module: module.into(),
            name: name.into(),
            source_location: loc.map(str::to_string),
            script: script.map(str::to_string),
            iseq_kind: "method".into(),
            ..Default::default()
        }
    }

    #[test]
    fn merges_processes_and_compares_with_facts() {
        let tmpl = GeneratedScript {
            sha256: "t".into(),
            path: "/app/app/views/a/index.html.erb".into(),
            caller: Some("/gems/actionview/lib/action_view/template.rb:509".into()),
            phase: "test".into(),
            count: 1,
            ..Default::default()
        };
        let tmpl2 = GeneratedScript {
            sha256: "u".into(),
            path: "/app/app/views/a/_row.html.erb".into(),
            ..tmpl.clone()
        };
        let gen_rel = GeneratedScript {
            sha256: "r".into(),
            path: "/gems/ar/delegation.rb".into(),
            caller_label: Some("ActiveRecord::Delegation::GeneratedRelationMethods#generate_method".into()),
            caller: Some("/gems/ar/delegation.rb:70".into()),
            ..tmpl.clone()
        };
        let p1 = Partial {
            pid: 1,
            ruby_description: "ruby 4.0.7 (revision fixture)".into(),
            app_root: "/app".into(),
            defined_after_boot: vec![
                om("Article", "title", Some("/gems/am/attr.rb:1"), None),
                om("View", "_index_123", Some("/app/app/views/a/index.html.erb:0"), Some("t")),
                om("View", "_row_9", Some("/app/app/views/a/_row.html.erb:0"), Some("u")),
            ],
            generated_scripts: vec![tmpl.clone(), tmpl2],
            types: vec![MethodTypes {
                module: "Article".into(),
                name: "summary".into(),
                calls: 2,
                returns: BTreeMap::from([("String".into(), 2)]),
                ..Default::default()
            }],
            ..Default::default()
        };
        let p2 = Partial {
            pid: 2,
            ruby_description: "ruby 4.0.7 (revision fixture)".into(),
            app_root: "/app".into(),
            generated_stats: GeneratedStats {
                linking_decline: Some("iseq_identity_unavailable: fresh wrappers".into()),
                ..Default::default()
            },
            defined_after_boot: vec![
                om("Article", "title", Some("/gems/am/attr.rb:1"), None),
                om("Rel", "recent", Some("/gems/ar/delegation.rb:70"), Some("r")),
                om("ArticleTest", "test_x", Some("/app/test/models/article_test.rb:3"), None),
                om("Capybara::DSL", "visit", Some("/gems/capybara-3/lib/dsl.rb:5"), None),
            ],
            generated_scripts: vec![tmpl, gen_rel],
            types: vec![MethodTypes {
                module: "Article".into(),
                name: "summary".into(),
                calls: 1,
                saturated: true,
                returns: BTreeMap::from([("NilClass".into(), 1)]),
                ..Default::default()
            }],
            ..Default::default()
        };
        let mut o = merge_parts(vec![p1, p2]);
        assert_eq!(o.processes, vec![1, 2]);
        assert_eq!(o.defined_after_boot.len(), 6);
        assert_eq!(o.generated_scripts.len(), 3);
        assert_eq!(o.generated_scripts.iter().find(|s| s.sha256 == "t").unwrap().count, 2);
        assert_eq!(serde_json::to_value(&o).unwrap()["generated_stats"]["linking_decline"],
                   "iseq_identity_unavailable: fresh wrappers");
        let t = &o.types[0];
        assert_eq!((t.calls, t.saturated, t.returns.len()), (3, true, 2));

        let facts = Facts {
            ruby_description: "ruby 4.0.7 (revision fixture)".into(),
            modules: vec![Module {
                name: "Article".into(),
                methods: vec![Method {
                    name: "title".into(),
                    ..Default::default()
                }],
                ..Default::default()
            }],
            compiled_templates: vec![CompiledTemplate {
                identifier: "/app/app/views/a/index.html.erb".into(),
                ..Default::default()
            }],
            gems: vec![Gem {
                name: "capybara".into(),
                path: "/gems/capybara-3".into(),
                ..Default::default()
            }],
            ..Default::default()
        };
        let c = compare(&o, &facts, Path::new("facts.json"), None).unwrap();
        assert_eq!((c.in_facts, c.templates_compiled_in_facts, c.not_in_facts), (1, 1, 4));
        let src = |name: &str| c.methods.iter().find(|m| m.name == name).unwrap().source.clone();
        assert_eq!(src("_row_9"), "template");
        assert_eq!(
            src("recent"),
            "generated (ActiveRecord::Delegation::GeneratedRelationMethods#generate_method)"
        );
        assert_eq!(src("test_x"), "app test code");
        assert_eq!(src("visit"), "gem capybara");
        o.comparison = Some(c);
        assert!(summary(&o, Path::new("observed.json"), Some(1.0)).contains("4 not in facts"));
    }
}
