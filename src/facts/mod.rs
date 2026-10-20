//! Boot facts: run `gem/exe/lowrail-facts` inside an app, load the
//! `facts.json` it writes, and summarize it. See docs/FORMATS.md.

pub mod generated;
pub mod origin;
pub mod schema;

pub use origin::{Classifier, MethodOrigin, Origin};
pub use schema::Facts;

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;

const USAGE: &str = "usage: lowrail facts APP [--out PATH] [--no-boot] [--origins] [--show MOD#METH]...
                         [--no-materialize] [--no-capture]
  boots APP (bundle exec, RAILS_ENV=test), materializes its lazily generated
  surface (docs/PLAN.md 9.4), captures generated scripts into
  APP/.lowrail/generated/, writes APP/.lowrail/facts.json (or PATH) and
  prints a summary;
  --no-boot summarizes an existing facts file;
  --origins also lists every app-relevant method with its origin;
  --show prints a method's origin and generated body (Mod#m, Mod.m)";

pub fn load(path: impl AsRef<Path>) -> Result<Facts, String> {
    let path = path.as_ref();
    let bytes = std::fs::read(path).map_err(|e| format!("{}: {e}", path.display()))?;
    let facts: Facts =
        serde_json::from_slice(&bytes).map_err(|e| format!("{}: {e}", path.display()))?;
    if facts.format != 1 {
        return Err(format!(
            "{}: unsupported facts format {}",
            path.display(),
            facts.format
        ));
    }
    Ok(facts)
}

/// Lowrail's Ruby gem. For now the crate's own `gem/` directory.
pub fn gem_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("gem")
}

/// Boots `app` and writes its facts to `out`.
pub fn dump(app: &Path, out: &Path) -> Result<(), String> {
    dump_with(app, out, &[])
}

/// Boots `app` and writes its facts to `out`, passing `flags` to
/// lowrail-facts (`--no-materialize`, `--no-capture`, `--no-census`).
pub fn dump_with(app: &Path, out: &Path, flags: &[&str]) -> Result<(), String> {
    let exe = gem_dir().join("exe/lowrail-facts");
    let status = Command::new("bundle")
        .args(["exec", "ruby"])
        .arg(&exe)
        .arg(out)
        .args(flags)
        .current_dir(app)
        .status()
        .map_err(|e| format!("bundle exec ruby {}: {e}", exe.display()))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!(
            "lowrail-facts failed in {} ({status})",
            app.display()
        ))
    }
}

pub fn cli(args: &[String]) -> Result<(), String> {
    let mut app = None;
    let mut out = None;
    let mut boot = true;
    let mut list_origins = false;
    let mut show = Vec::new();
    let mut flags = Vec::new();
    let mut it = args.iter();
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--out" => out = Some(PathBuf::from(it.next().ok_or(USAGE)?)),
            "--no-boot" => boot = false,
            "--origins" => list_origins = true,
            "--show" => show.push(it.next().ok_or(USAGE)?.clone()),
            "--no-materialize" => flags.push("--no-materialize"),
            "--no-capture" => flags.push("--no-capture"),
            s if !s.starts_with('-') && app.is_none() => app = Some(PathBuf::from(s)),
            _ => return Err(USAGE.into()),
        }
    }
    let app = app.ok_or(USAGE)?;
    let app = app
        .canonicalize()
        .map_err(|e| format!("{}: {e}", app.display()))?;
    let out = out.unwrap_or_else(|| app.join(".lowrail/facts.json"));
    let out = if out.is_absolute() {
        out
    } else {
        std::env::current_dir()
            .map_err(|e| e.to_string())?
            .join(out)
    };
    if boot {
        if let Some(dir) = out.parent() {
            std::fs::create_dir_all(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
        }
        dump_with(&app, &out, &flags)?;
    }
    let facts = load(&out)?;
    let size = std::fs::metadata(&out).map(|m| m.len()).unwrap_or(0);
    print!("{}", summary(&facts, &out, size));
    let gen_dir = generated_dir(&out);
    if list_origins {
        for o in Classifier::new(&facts).with_generated_dir(&gen_dir).app_relevant() {
            let sep = if o.method.singleton { "." } else { "#" };
            let body = o
                .generated
                .as_ref()
                .map(|g| format!("\tgenerated {}.rb:{} ({:?})", &g.script.sha256[..12], g.line, g.form))
                .unwrap_or_default();
            println!("{}{sep}{}\t{:?}{body}", o.module.name, o.method.name, o.origin);
        }
    }
    for spec in &show {
        print!("{}", show_method(&facts, &gen_dir, spec)?);
    }
    Ok(())
}

/// `generated/` next to a facts file.
pub fn generated_dir(facts_path: &Path) -> PathBuf {
    facts_path
        .parent()
        .unwrap_or(Path::new("."))
        .join("generated")
}

/// Origin and generated body of `Mod#meth` / `Mod.meth`.
pub fn show_method(facts: &Facts, gen_dir: &Path, spec: &str) -> Result<String, String> {
    use std::fmt::Write;
    let (module, name, singleton) = match spec.rfind(['#', '.']) {
        Some(i) => (&spec[..i], &spec[i + 1..], spec.as_bytes()[i] == b'.'),
        None => return Err(format!("--show {spec}: expected Mod#meth or Mod.meth")),
    };
    let m = facts
        .modules
        .iter()
        .find(|m| m.name == module)
        .ok_or_else(|| format!("{spec}: no module {module}"))?;
    let meth = m
        .methods
        .iter()
        .find(|x| x.name == name && x.singleton == singleton)
        .ok_or_else(|| format!("{spec}: no such method"))?;
    let mut c = Classifier::new(facts).with_generated_dir(gen_dir);
    let mut s = String::new();
    let _ = writeln!(s, "{spec}  owner {}  source {}", meth.owner, meth.source_location.as_deref().unwrap_or("-"));
    let _ = writeln!(s, "  origin: {:?}", c.classify(m, meth));
    match c.generated(meth) {
        Some(g) => {
            let sc = &g.script;
            let _ = writeln!(
                s,
                "  generated: {} line {} ({:?}, {:?}); {} into {} at {}:{} from {} ({})",
                g.file.display(),
                g.line,
                g.form,
                g.via,
                sc.kind,
                sc.module.as_deref().unwrap_or("?"),
                sc.path,
                sc.lineno,
                sc.caller.as_deref().unwrap_or("?"),
                sc.caller_label.as_deref().unwrap_or("?"),
            );
            for line in g.source.lines() {
                let _ = writeln!(s, "  | {line}");
            }
        }
        None => {
            let _ = writeln!(s, "  generated: -");
        }
    }
    Ok(s)
}

/// Human-readable summary: counts, timings, and origins of app methods.
pub fn summary(facts: &Facts, path: &Path, size: u64) -> String {
    use std::fmt::Write;
    let mut s = String::new();
    let w = &mut s;
    let methods = || facts.modules.iter().flat_map(|m| &m.methods);
    let _ = writeln!(w, "facts: {} ({:.1} MB)", path.display(), size as f64 / 1e6);
    let _ = writeln!(
        w,
        "ruby: {}\nrails: {}  yjit: {}",
        facts.ruby_description,
        facts.rails_version.as_deref().unwrap_or("-"),
        facts.yjit
    );
    let t = |k: &str| facts.timings.get(k).copied().unwrap_or(f64::NAN);
    let _ = writeln!(
        w,
        "timings: boot {:.2}s, eager_load {:.2}s, dump {:.2}s",
        t("boot_seconds"),
        t("eager_load_seconds"),
        t("dump_seconds")
    );
    let st = &facts.module_stats;
    let _ = writeln!(
        w,
        "modules: {} named ({} anonymous, {} nested in anonymous, {} singleton classes skipped)",
        facts.modules.len(),
        st.anonymous,
        st.anonymous_rooted,
        st.singleton_classes
    );
    let _ = writeln!(
        w,
        "methods: {} {}",
        methods().count(),
        counts(methods().map(|m| m.iseq_kind.clone()))
    );
    let classifier = Classifier::new(facts);
    let app_owned: Vec<_> = methods()
        .filter(|m| {
            m.source_location
                .as_deref()
                .map(|l| l.strip_prefix("(eval at ").unwrap_or(l))
                .and_then(schema::split_location)
                .is_some_and(|(p, _)| classifier.in_app(p))
        })
        .collect();
    let _ = writeln!(
        w,
        "app-owned methods (source under app): {} {}",
        app_owned.len(),
        counts(app_owned.iter().map(|m| m.iseq_kind.clone()))
    );
    let skipped = facts.errors.iter().filter(|e| e.kind == "skipped").count();
    let _ = writeln!(
        w,
        "models: {}  controllers: {}  routes: {}  gems: {}  loaded features: {}  errors: {} (+{} skipped)",
        facts.models.len(),
        facts.controllers.len(),
        facts.routes.len(),
        facts.gems.len(),
        facts.load_path_features.len(),
        facts.errors.len() - skipped,
        skipped
    );
    let _ = writeln!(
        w,
        "templates: {} {}",
        facts.templates.len(),
        counts(
            facts
                .templates
                .iter()
                .map(|t| t.handler.rsplit("::").next().unwrap_or("").to_string())
        )
    );
    if !facts.materialize.is_empty() {
        let _ = writeln!(w, "materialize (step: seconds, +modules, +methods, +generated scripts):");
        if let Some(c) = &facts.census_boot {
            let _ = writeln!(
                w,
                "  {:<22} {:>6} {:>7} {:>8} {:>6}",
                "after boot", "", c.modules, c.methods, c.scripts
            );
        }
        for st in &facts.materialize {
            let n = |x: Option<i64>| x.map_or("-".into(), |v| format!("+{v}"));
            let _ = writeln!(
                w,
                "  {:<22} {:>5.2}s {:>7} {:>8} {:>6}{}{}",
                st.step,
                st.seconds,
                n(st.modules),
                n(st.methods),
                n(st.scripts),
                if st.errors > 0 { format!("  {} errors", st.errors) } else { String::new() },
                st.note.as_deref().map(|n| format!("  ({n})")).unwrap_or_default()
            );
        }
    }
    if let Some(g) = &facts.generated_stats {
        let tagged = methods().filter(|m| m.script.is_some()).count();
        let _ = writeln!(
            w,
            "generated scripts: {} distinct ({} compilations, {:.1} MB, hook {:.3}s) {}; methods compiled from one: {tagged}",
            g.scripts,
            g.compilations,
            g.bytes as f64 / 1e6,
            g.hook_seconds,
            counts(facts.generated_scripts.iter().map(|s| s.phase.split(':').next().unwrap_or("").to_string())),
        );
        if let Some(reason) = &g.linking_decline {
            let _ = writeln!(w, "generated identity linking refused: {reason}");
        }
    }
    for e in facts.errors.iter().filter(|e| e.kind != "skipped").take(10) {
        let _ = writeln!(w, "  error: {}: {}", e.r#where, e.error);
    }

    let mut classifier = Classifier::new(facts).with_generated_dir(generated_dir(path));
    let origins = classifier.app_relevant();
    let _ = writeln!(w, "origins of app-relevant methods: {}", origins.len());
    let linked: Vec<_> = origins.iter().filter_map(|o| o.generated.as_ref()).collect();
    if !linked.is_empty() || facts.generated_stats.is_some() {
        let _ = writeln!(
            w,
            "  with generated body: {} {}",
            linked.len(),
            counts(linked.iter().map(|g| format!("{:?}", g.form).to_lowercase()))
        );
    }
    let mut by_cat: BTreeMap<&str, Vec<&MethodOrigin>> = BTreeMap::new();
    for o in &origins {
        by_cat.entry(o.origin.category()).or_default().push(o);
    }
    for (cat, list) in &by_cat {
        let detail = match *cat {
            "def" => {
                let app = list
                    .iter()
                    .filter(|o| matches!(o.origin, Origin::Def { in_app: true, .. }))
                    .count();
                format!("(in app {app}, in gems {})", list.len() - app)
            }
            "generated in app source" | "generated in gem" => {
                counts(list.iter().map(|o| match &o.origin {
                    Origin::GeneratedInApp { generator, .. }
                    | Origin::GeneratedInGem { generator, .. } => generator.clone(),
                    _ => unreachable!(),
                }))
            }
            "no source" => counts(list.iter().map(|o| o.method.iseq_kind.clone())),
            _ => {
                let mut d = String::new();
                for o in list.iter().take(5) {
                    if let Origin::Unresolved { reason } = &o.origin {
                        let _ = write!(d, "\n    {}#{}: {reason}", o.module.name, o.method.name);
                    }
                }
                d
            }
        };
        let _ = writeln!(w, "  {cat}: {} {detail}", list.len());
    }
    s
}

/// "{a: 3, b: 1}" ordered by count, then name.
fn counts(items: impl Iterator<Item = String>) -> String {
    let mut map: BTreeMap<String, usize> = BTreeMap::new();
    for i in items {
        *map.entry(i).or_default() += 1;
    }
    let mut v: Vec<_> = map.into_iter().collect();
    v.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    let parts: Vec<String> = v.into_iter().map(|(k, n)| format!("{k} {n}")).collect();
    format!("[{}]", parts.join(", "))
}

#[cfg(test)]
mod corpus_tests {
    use super::*;
    use crate::facts::generated::{Form, Via};

    /// Boots real-blog (skipped when the corpus or its Ruby is missing),
    /// then links generated methods to the exact def in their script.
    #[test]
    fn real_blog_generated_methods_link_to_their_def() {
        let corpus = std::env::var_os("LOWRAIL_TEST_CORPUS_ROOT").map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(".corpus"));
        let app = corpus.join("real-blog-r4");
        if !app.join("Gemfile.lock").exists() {
            eprintln!("skipped: no {}", app.display());
            return;
        }
        let ok = Command::new("bundle")
            .args(["exec", "ruby", "-e", "exit(RUBY_VERSION >= '4.0' ? 0 : 1)"])
            .current_dir(&app)
            .output()
            .is_ok_and(|o| o.status.success());
        if !ok {
            eprintln!("skipped: bundle exec ruby (4.0+) not available in {}", app.display());
            return;
        }
        let dir = std::env::temp_dir().join(format!("lowrail-corpus-{}", std::process::id()));
        let out = dir.join("facts.json");
        dump_with(&app, &out, &["--no-census"]).unwrap();
        let facts = load(&out).unwrap();
        assert!(facts.materialize.iter().any(|s| s.step == "templates"));
        assert!(facts.generated_scripts.len() > 500, "{}", facts.generated_scripts.len());

        let mut c = Classifier::new(&facts).with_generated_dir(generated_dir(&out));
        let attrs = facts
            .modules
            .iter()
            .find(|m| m.name == "Article::GeneratedAttributeMethods")
            .unwrap();
        let title = attrs.methods.iter().find(|m| m.name == "title").unwrap();
        let g = c.generated(title).expect("title links to its generated script");
        assert_eq!(g.form, Form::Def);
        assert!(g.source.starts_with("def title;") && g.source.contains("_read_attribute('title')"), "{}", g.source);

        let origins = c.app_relevant();
        let templates = origins.iter().filter(|o| matches!(o.origin, Origin::Template { .. })).count();
        if let Some(reason) = facts.generated_stats.as_ref().and_then(|s| s.linking_decline.as_deref()) {
            assert!(reason.starts_with("iseq_identity_unavailable:"), "{reason}");
            assert!(facts.modules.iter().flat_map(|m| &m.methods).all(|m| m.script.is_none()));
            assert_eq!(g.via, Via::Location, "source display is not compilation provenance");
            assert_eq!(templates, 0, "no identity-based template attribution");
            assert!(facts.compiled_templates.iter().filter(|t| t.in_app == Some(true)).count() >= 10);
            assert!(origins.iter().filter_map(|o| o.generated.as_ref()).all(|g| g.via == Via::Location));
            assert!(summary(&facts, &out, 0).contains(reason));
        } else {
            assert_eq!(g.via, Via::Identity);
            assert!(templates >= 10, "{templates} template methods");
            let linked = origins.iter().filter(|o| o.generated.is_some()).count();
            assert!(linked > 250, "{linked} app-relevant methods with a generated body");
        }
        std::fs::remove_dir_all(&dir).ok();
    }
}
