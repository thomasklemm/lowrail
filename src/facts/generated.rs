//! Generated code: links a method whose body was compiled from an eval'd
//! string (`class_eval <<~RUBY`, `module_eval(src, __FILE__, __LINE__)`,
//! a compiled template, ...) to the captured script and the exact `def`
//! inside it, so its generated body can be shown and analyzed.
//!
//! The dumper records each script once (`generated_scripts` in facts.json,
//! source in `generated/<sha256>.rb`) and tags methods compiled inside one
//! with its digest (`Method::script`, by ISeq identity). Methods without a
//! tag are matched by location as a fallback: same eval path, line inside
//! the script, and a `def` of that name at the relative line.

use super::origin::SourceIndex;
use super::schema::{Facts, GeneratedScript, Method, split_location};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

/// How the body appears in the script.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Form {
    /// `def name` starts on the line.
    Def,
    /// A call starts on the line (`define_method(:x) { ... }` inside the
    /// script); the source is the whole call.
    Call,
    /// Nothing parseable starts there; the source is that line.
    Line,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Via {
    /// The dumper matched the method's ISeq to the script.
    Identity,
    /// Matched by eval path and line range.
    Location,
}

/// A method's generated body.
#[derive(Debug, Clone)]
pub struct GeneratedDef {
    pub script: GeneratedScript,
    /// Sidecar file holding the script source.
    pub file: PathBuf,
    /// 1-based line inside the script.
    pub line: u32,
    pub form: Form,
    pub via: Via,
    pub source: String,
}

/// Compiled by ActionView::Template#compile (module_eval of the handler
/// output, with the template file as path).
pub fn is_template(s: &GeneratedScript) -> bool {
    !s.path.starts_with('(')
        && !s.path.ends_with(".rb")
        && s
            .caller
            .as_deref()
            .is_some_and(|c| c.contains("action_view/template.rb"))
}

pub struct Generated<'f> {
    dir: PathBuf,
    by_sha: HashMap<&'f str, Vec<&'f GeneratedScript>>,
    by_path: HashMap<&'f str, Vec<&'f GeneratedScript>>,
    sources: HashMap<String, Option<(Vec<u8>, SourceIndex)>>,
}

impl<'f> Generated<'f> {
    /// `dir` holds `<sha256>.rb` files (normally next to facts.json).
    pub fn new(facts: &'f Facts, dir: impl AsRef<Path>) -> Self {
        let mut by_sha: HashMap<&str, Vec<&GeneratedScript>> = HashMap::new();
        let mut by_path: HashMap<&str, Vec<&GeneratedScript>> = HashMap::new();
        for s in &facts.generated_scripts {
            by_sha.entry(s.sha256.as_str()).or_default().push(s);
            by_path.entry(s.path.as_str()).or_default().push(s);
        }
        Generated {
            dir: dir.as_ref().to_path_buf(),
            by_sha,
            by_path,
            sources: HashMap::new(),
        }
    }

    /// The script entry a method is tagged with.
    pub fn script_of(&self, method: &Method) -> Option<&'f GeneratedScript> {
        let sha = method.script.as_deref()?;
        self.by_sha.get(sha)?.first().copied()
    }

    /// The generated body of `method`, if it was compiled from a script.
    pub fn link(&mut self, method: &Method) -> Option<GeneratedDef> {
        let (path, line) = method.source_location.as_deref().and_then(split_location)?;
        let name = method.def_name();
        if let Some(sha) = method.script.as_deref() {
            // The digest is certain; the entry (several sites can compile
            // the same text) is the one whose range holds the line.
            let candidates = self.by_sha.get(sha)?.clone();
            let script = candidates
                .iter()
                .find(|s| s.path == path && contains(s, line))
                .or(candidates.first())
                .copied()?;
            let rel = relative(script, line).unwrap_or(1);
            return self.body(script, rel, name, Via::Identity);
        }
        let candidates: Vec<&GeneratedScript> = self
            .by_path
            .get(path)?
            .iter()
            .filter(|s| contains(s, line))
            .copied()
            .collect();
        let mut found: Option<GeneratedDef> = None;
        for script in candidates {
            let rel = relative(script, line)?;
            if let Some(def) = self.body(script, rel, name, Via::Location)
                && def.form == Form::Def
            {
                match &found {
                    // Two different texts define it there: ambiguous.
                    Some(f) if f.script.sha256 != def.script.sha256 => return None,
                    Some(_) => {}
                    None => found = Some(def),
                }
            }
        }
        found
    }

    fn body(&mut self, script: &GeneratedScript, rel: u32, name: &str, via: Via) -> Option<GeneratedDef> {
        let file = self.dir.join(format!("{}.rb", script.sha256));
        let (src, index) = self
            .sources
            .entry(script.sha256.clone())
            .or_insert_with(|| {
                let src = std::fs::read(&file).ok()?;
                let index = SourceIndex::parse(&src);
                Some((src, index))
            })
            .as_ref()?;
        let (form, span) = if let Some(span) = index.def_span(rel, name) {
            (Form::Def, span)
        } else if let Some(span) = index.call_span(rel) {
            (Form::Call, span)
        } else {
            (Form::Line, line_span(src, rel)?)
        };
        Some(GeneratedDef {
            script: script.clone(),
            file,
            line: rel,
            form,
            via,
            source: String::from_utf8_lossy(&src[span.0..span.1]).into_owned(),
        })
    }
}

fn contains(s: &GeneratedScript, line: u32) -> bool {
    relative(s, line).is_some_and(|rel| rel <= s.lines.max(1))
}

/// Script-relative 1-based line of an absolute reported line.
fn relative(s: &GeneratedScript, line: u32) -> Option<u32> {
    let rel = line as i64 - s.lineno + 1;
    (rel >= 1).then_some(rel as u32)
}

fn line_span(src: &[u8], line: u32) -> Option<(usize, usize)> {
    let mut start = 0;
    for _ in 1..line {
        start += src[start..].iter().position(|b| *b == b'\n')? + 1;
    }
    let end = src[start..]
        .iter()
        .position(|b| *b == b'\n')
        .map_or(src.len(), |e| start + e);
    Some((start, end))
}

#[cfg(test)]
mod tests {
    use super::*;

    const SCRIPT: &str = "def title\n  _read_attribute(\"title\")\nend\n\ndefine_method(:shout) do\n  title.upcase\nend\n";

    fn fixture(dir: &Path, path: &str, lineno: i64) -> (Facts, String) {
        let sha = "ab".repeat(32);
        std::fs::create_dir_all(dir).unwrap();
        std::fs::write(dir.join(format!("{sha}.rb")), SCRIPT).unwrap();
        let facts = Facts {
            generated_scripts: vec![GeneratedScript {
                sha256: sha.clone(),
                lines: 7,
                path: path.into(),
                lineno,
                kind: "module_eval".into(),
                caller: Some("/gems/actionview/lib/action_view/template.rb:509".into()),
                ..Default::default()
            }],
            ..Default::default()
        };
        (facts, sha)
    }

    fn method(name: &str, loc: &str, script: Option<&str>) -> Method {
        Method {
            name: name.into(),
            source_location: Some(loc.into()),
            script: script.map(str::to_string),
            ..Default::default()
        }
    }

    #[test]
    fn links_by_identity_and_by_location() {
        let dir = std::env::temp_dir().join(format!("lowrail-gen-{}", std::process::id()));
        // module_eval(src, "/gems/ar/attribute_methods.rb", 40)
        let (facts, sha) = fixture(&dir, "/gems/ar/attribute_methods.rb", 40);
        let mut g = Generated::new(&facts, &dir);

        let d = g
            .link(&method("title", "/gems/ar/attribute_methods.rb:40", Some(&sha)))
            .unwrap();
        assert_eq!((d.line, d.form.clone(), d.via.clone()), (1, Form::Def, Via::Identity));
        assert_eq!(d.source, "def title\n  _read_attribute(\"title\")\nend");

        // Untagged: found by location, only when a def of that name is there.
        let d = g
            .link(&method("title", "/gems/ar/attribute_methods.rb:40", None))
            .unwrap();
        assert_eq!(d.via, Via::Location);
        assert!(g.link(&method("other", "/gems/ar/attribute_methods.rb:40", None)).is_none());
        assert!(g.link(&method("title", "/gems/ar/attribute_methods.rb:39", None)).is_none());
        assert!(g.link(&method("title", "/gems/ar/other.rb:40", None)).is_none());

        // define_method inside the script: the whole call.
        let d = g
            .link(&method("shout", "/gems/ar/attribute_methods.rb:44", Some(&sha)))
            .unwrap();
        assert_eq!((d.line, d.form.clone()), (5, Form::Call));
        assert!(d.source.starts_with("define_method(:shout) do") && d.source.ends_with("end"));
        assert!(!is_template(&d.script), "a .rb path is Ruby source");
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn links_eval_paths_and_templates() {
        let dir = std::env::temp_dir().join(format!("lowrail-gen2-{}", std::process::id()));
        let (facts, _) = fixture(&dir, "(eval at /app/models/a.rb:3)", 1);
        let mut g = Generated::new(&facts, &dir);
        let d = g
            .link(&method("title", "(eval at /app/models/a.rb:3):1", None))
            .unwrap();
        assert_eq!(d.form, Form::Def);
        std::fs::remove_dir_all(&dir).ok();

        // A template compiled with offset 0: method reported at line 0.
        let (facts, sha) = fixture(&dir, "/app/views/a/index.html.erb", 0);
        let mut g = Generated::new(&facts, &dir);
        let d = g
            .link(&method("title", "/app/views/a/index.html.erb:0", Some(&sha)))
            .unwrap();
        assert_eq!(d.line, 1);
        assert!(is_template(&d.script));
        std::fs::remove_dir_all(&dir).ok();
    }
}
