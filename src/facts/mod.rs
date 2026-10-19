//! Boot facts: run `gem/exe/lowrail-facts` inside an app, load the
//! `facts.json` it writes, and summarize it. See docs/FORMATS.md.

pub mod origin;
pub mod schema;

pub use origin::{Classifier, MethodOrigin, Origin};
pub use schema::Facts;

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;

const USAGE: &str = "usage: lowrail facts APP [--out PATH] [--no-boot] [--origins]
  boots APP (bundle exec, RAILS_ENV=test, eager_load!), writes
  APP/.lowrail/facts.json (or PATH) and prints a summary;
  --no-boot summarizes an existing facts file;
  --origins also lists every app-relevant method with its origin";

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
    let exe = gem_dir().join("exe/lowrail-facts");
    let status = Command::new("bundle")
        .args(["exec", "ruby"])
        .arg(&exe)
        .arg(out)
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
    let mut it = args.iter();
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--out" => out = Some(PathBuf::from(it.next().ok_or(USAGE)?)),
            "--no-boot" => boot = false,
            "--origins" => list_origins = true,
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
        dump(&app, &out)?;
    }
    let facts = load(&out)?;
    let size = std::fs::metadata(&out).map(|m| m.len()).unwrap_or(0);
    print!("{}", summary(&facts, &out, size));
    if list_origins {
        for o in Classifier::new(&facts).app_relevant() {
            let sep = if o.method.singleton { "." } else { "#" };
            println!("{}{sep}{}\t{:?}", o.module.name, o.method.name, o.origin);
        }
    }
    Ok(())
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
    for e in facts.errors.iter().filter(|e| e.kind != "skipped").take(10) {
        let _ = writeln!(w, "  error: {}: {}", e.r#where, e.error);
    }

    let mut classifier = Classifier::new(facts);
    let origins = classifier.app_relevant();
    let _ = writeln!(w, "origins of app-relevant methods: {}", origins.len());
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
