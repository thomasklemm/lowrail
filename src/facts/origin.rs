//! Where did a booted method come from? The first "Prism + boot" synergy:
//! the boot says *where* a method's body lives (`source_location`), Prism says
//! *what* is written there.
//!
//! - a `def` with the same name starts on that line: [`Origin::Def`];
//! - an app file has a call there (`has_many`, `delegate`, `attr_accessor`,
//!   `define_method`, `class_eval`, ...): [`Origin::GeneratedInApp`];
//! - otherwise the body comes from library code (a `class_eval` heredoc or a
//!   `define_method` block inside some gem method): [`Origin::GeneratedInGem`],
//!   named after the app-level macro when the boot facts reveal it
//!   (association reader → `has_many`), else after the enclosing gem method.

use super::generated::{self, Generated, GeneratedDef};
use super::schema::{Facts, Method, Module, split_location};
use ruby_prism::Visit;
use std::collections::HashMap;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Origin {
    /// No Ruby source: cfunc, optimized struct member, ...
    NoSource { iseq_kind: String },
    /// `def <name>` starts on the reported line.
    Def {
        file: String,
        line: u32,
        in_app: bool,
    },
    /// A macro call in app source at the reported line generated the method.
    GeneratedInApp {
        generator: String,
        file: String,
        line: u32,
    },
    /// Library code generated it. `site` is the enclosing gem method
    /// (`ActiveRecord::Scoping::Named::ClassMethods#scope`) when found.
    GeneratedInGem {
        generator: String,
        site: String,
        gem: Option<String>,
    },
    /// A compiled template method (ActionView::Template#compile).
    Template { file: String },
    /// Source could not be read or nothing matches at that line.
    Unresolved { reason: String },
}

impl Origin {
    pub fn category(&self) -> &'static str {
        match self {
            Origin::NoSource { .. } => "no source",
            Origin::Def { .. } => "def",
            Origin::GeneratedInApp { .. } => "generated in app source",
            Origin::GeneratedInGem { .. } => "generated in gem",
            Origin::Template { .. } => "template",
            Origin::Unresolved { .. } => "unresolved",
        }
    }
}

/// One classified method.
#[derive(Debug, Clone)]
pub struct MethodOrigin<'f> {
    pub module: &'f Module,
    pub method: &'f Method,
    pub origin: Origin,
    /// The generated body, when the method was compiled from an eval'd
    /// script and the classifier has the generated sources.
    pub generated: Option<GeneratedDef>,
}

/// What Prism sees in one file, by 1-based line.
#[derive(Debug, Default)]
pub struct SourceIndex {
    /// `def` names starting on a line (singleton defs included).
    defs: HashMap<u32, Vec<String>>,
    /// Call names on a line, outermost first; receiverless calls are marked.
    calls: HashMap<u32, Vec<(String, bool)>>,
    /// (first line, last line, qualified name) of every def, outer first.
    def_ranges: Vec<(u32, u32, String)>,
    /// Byte span of every def by first line and name.
    def_spans: HashMap<(u32, String), (usize, usize)>,
    /// Byte span of the outermost call starting on a line.
    call_spans: HashMap<u32, (usize, usize)>,
}

impl SourceIndex {
    pub fn parse(source: &[u8]) -> SourceIndex {
        let result = ruby_prism::parse(source);
        let mut v = Indexer {
            lines: LineMap::new(source),
            index: SourceIndex::default(),
            nesting: Vec::new(),
            singleton: 0,
        };
        v.visit(&result.node());
        v.index
    }

    /// Does a `def name` start on `line`?
    pub fn def_at(&self, line: u32, name: &str) -> bool {
        self.defs
            .get(&line)
            .is_some_and(|names| names.iter().any(|n| n == name))
    }

    /// The call that best explains a method generated at `line`: the first
    /// receiverless call (a macro), else the outermost call.
    pub fn call_at(&self, line: u32) -> Option<&str> {
        let calls = self.calls.get(&line)?;
        calls
            .iter()
            .find(|(_, recv_less)| *recv_less)
            .or(calls.first())
            .map(|(n, _)| n.as_str())
    }

    /// Byte span of `def name` starting on `line`.
    pub fn def_span(&self, line: u32, name: &str) -> Option<(usize, usize)> {
        self.def_spans.get(&(line, name.to_string())).copied()
    }

    /// Byte span of the outermost call starting on `line`.
    pub fn call_span(&self, line: u32) -> Option<(usize, usize)> {
        self.call_spans.get(&line).copied()
    }

    /// Innermost def containing `line`, as `Nesting#name` / `Nesting.name`.
    pub fn enclosing_def(&self, line: u32) -> Option<&str> {
        self.def_ranges
            .iter()
            .filter(|(a, b, _)| *a <= line && line <= *b)
            .min_by_key(|(a, b, _)| b - a)
            .map(|(_, _, n)| n.as_str())
    }
}

/// Classifies the location of a method body in an already indexed file.
/// `in_app` decides between "generated in app" and "generated in gem" when
/// no def matches. Returns `None` for an app line that explains nothing.
pub fn classify_line(
    index: &SourceIndex,
    line: u32,
    def_name: &str,
    in_app: bool,
    eval: bool,
) -> Option<LineOrigin> {
    if !eval && index.def_at(line, def_name) {
        return Some(LineOrigin::Def);
    }
    if in_app {
        return index.call_at(line).map(|c| LineOrigin::Call(c.to_string()));
    }
    // Library code: name the method that generated it, or, at class level
    // (e.g. inside an `included do` block), the macro call on that line.
    match index.enclosing_def(line) {
        Some(site) => Some(LineOrigin::InsideDef(site.to_string())),
        None => Some(LineOrigin::GemCall(index.call_at(line).map(str::to_string))),
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LineOrigin {
    /// A `def` of that name starts on the line.
    Def,
    /// App source: the macro call on the line.
    Call(String),
    /// Library source: the innermost enclosing def (`Mod::Name#meth`).
    InsideDef(String),
    /// Library source outside any def: the call on the line, if any.
    GemCall(Option<String>),
}

/// Well-known generator sites whose method name is not the public macro.
const SITE_GENERATORS: &[(&str, &str)] = &[
    ("ActiveSupport::ClassAttribute.redefine", "class_attribute"),
    (
        "ActionView::Layouts::ClassMethods#_write_layout_method",
        "layout",
    ),
    (
        "ActionDispatch::Routing::RouteSet#generate_url_helpers",
        "url_helpers",
    ),
    (
        "ActiveSupport::Callbacks::ClassMethods#define_callbacks",
        "define_callbacks",
    ),
];

/// Classifies methods against their source, caching parsed files.
pub struct Classifier<'f> {
    facts: &'f Facts,
    app_root: PathBuf,
    cache: HashMap<String, Option<SourceIndex>>,
    generated: Generated<'f>,
}

impl<'f> Classifier<'f> {
    pub fn new(facts: &'f Facts) -> Self {
        Classifier {
            facts,
            app_root: PathBuf::from(&facts.app_root),
            cache: HashMap::new(),
            generated: Generated::new(facts, PathBuf::new()),
        }
    }

    /// Reads generated script sources from `dir` (`generated/` next to
    /// facts.json) to attach generated bodies.
    pub fn with_generated_dir(mut self, dir: impl AsRef<Path>) -> Self {
        self.generated = Generated::new(self.facts, dir);
        self
    }

    /// The generated body of a method, if any.
    pub fn generated(&mut self, method: &Method) -> Option<GeneratedDef> {
        self.generated.link(method)
    }

    /// Is `path` app source (under the app root, but not vendored)?
    pub fn in_app(&self, path: &str) -> bool {
        let p = Path::new(path);
        p.starts_with(&self.app_root)
            && !["vendor", "node_modules", "tmp", ".lowrail"]
                .iter()
                .any(|d| p.starts_with(self.app_root.join(d)))
    }

    /// Is the module app-owned: defined in app source, or nested in an
    /// app-owned module (e.g. `Article::GeneratedAttributeMethods`)?
    pub fn app_module(&self, module: &Module, by_name: &HashMap<&str, &Module>) -> bool {
        let defined_here = |m: &Module| {
            m.const_source_location
                .as_deref()
                .and_then(split_location)
                .is_some_and(|(p, _)| self.in_app(p))
        };
        if defined_here(module) {
            return true;
        }
        // "Room._enum_methods_module", "Room.ancestors[3]": as app-owned as Room.
        let mut name = module.name.as_str();
        if module.synthetic
            && let Some((owner, _)) = name.split_once('.')
        {
            if by_name.get(owner).is_some_and(|m| defined_here(m)) {
                return true;
            }
            name = owner;
        }
        while let Some((outer, _)) = name.rsplit_once("::") {
            if by_name.get(outer).is_some_and(|m| defined_here(m)) {
                return true;
            }
            name = outer;
        }
        false
    }

    /// App-relevant methods: every method of an app-owned module plus every
    /// method whose body is in app source, each with its origin.
    pub fn app_relevant(&mut self) -> Vec<MethodOrigin<'f>> {
        let facts = self.facts;
        let by_name: HashMap<&str, &Module> =
            facts.modules.iter().map(|m| (m.name.as_str(), m)).collect();
        let mut out = Vec::new();
        for module in &facts.modules {
            let app_mod = self.app_module(module, &by_name);
            for method in &module.methods {
                let app_src = method
                    .source_location
                    .as_deref()
                    .and_then(split_location)
                    .is_some_and(|(p, _)| self.in_app(p));
                if app_mod || app_src {
                    let origin = self.classify(module, method);
                    let generated = self.generated.link(method);
                    out.push(MethodOrigin {
                        module,
                        method,
                        origin,
                        generated,
                    });
                }
            }
        }
        out
    }

    pub fn classify(&mut self, module: &Module, method: &Method) -> Origin {
        if let Some(script) = self.generated.script_of(method)
            && generated::is_template(script)
        {
            return Origin::Template {
                file: script.path.clone(),
            };
        }
        let Some(loc) = method.source_location.as_deref() else {
            return Origin::NoSource {
                iseq_kind: method.iseq_kind.clone(),
            };
        };
        let Some((path, line)) = split_location(loc) else {
            return Origin::Unresolved {
                reason: format!("bad source_location {loc}"),
            };
        };
        // "(eval at /abs/file.rb:12)": classify at the eval call site.
        let (path, line, eval) = match eval_site(path) {
            Some((p, l)) => (p, l, true),
            None if path.starts_with('(') => {
                return Origin::Unresolved {
                    reason: format!("eval without site: {path}"),
                };
            }
            None => (path, line, false),
        };
        let in_app = self.in_app(path);
        let Some(index) = self.index(path) else {
            return Origin::Unresolved {
                reason: format!("cannot read {path}"),
            };
        };
        match classify_line(index, line, method.def_name(), in_app, eval) {
            Some(LineOrigin::Def) => Origin::Def {
                file: path.to_string(),
                line,
                in_app,
            },
            Some(LineOrigin::Call(generator)) => Origin::GeneratedInApp {
                generator,
                file: path.to_string(),
                line,
            },
            Some(LineOrigin::InsideDef(site)) => {
                let generator = self.macro_for(module, method).unwrap_or_else(|| {
                    SITE_GENERATORS
                        .iter()
                        .find(|(s, _)| *s == site)
                        .map(|(_, g)| g.to_string())
                        .unwrap_or_else(|| short_site(&site))
                });
                Origin::GeneratedInGem {
                    generator,
                    site,
                    gem: self.gem_of(path),
                }
            }
            Some(LineOrigin::GemCall(call)) => {
                let site = format!("{path}:{line}");
                let generator = self
                    .macro_for(module, method)
                    .or(call)
                    .unwrap_or_else(|| "(unknown)".into());
                Origin::GeneratedInGem {
                    generator,
                    site,
                    gem: self.gem_of(path),
                }
            }
            None => Origin::Unresolved {
                reason: format!("no def or call at {path}:{line}"),
            },
        }
    }

    fn index(&mut self, path: &str) -> Option<&SourceIndex> {
        self.cache
            .entry(path.to_string())
            .or_insert_with(|| std::fs::read(path).ok().map(|src| SourceIndex::parse(&src)))
            .as_ref()
    }

    fn gem_of(&self, path: &str) -> Option<String> {
        self.facts
            .gems
            .iter()
            .filter(|g| !g.path.is_empty() && Path::new(path).starts_with(&g.path))
            .max_by_key(|g| g.path.len())
            .map(|g| g.name.clone())
    }

    /// Boot facts name the app-level macro behind Rails' generated modules.
    fn macro_for(&self, module: &Module, method: &Method) -> Option<String> {
        // Autosave/validation helpers on the model itself.
        if let Some(model) = self.facts.models.iter().find(|m| m.name == module.name) {
            let assoc = [
                "autosave_associated_records_for_",
                "validate_associated_records_for_",
            ]
            .iter()
            .find_map(|p| method.name.strip_prefix(p))?;
            return model
                .associations
                .iter()
                .find(|a| a.name == assoc)
                .map(|a| a.macro_.clone());
        }
        let (model_name, generated) = module.name.rsplit_once("::")?;
        let model = self.facts.models.iter().find(|m| m.name == model_name)?;
        let base = attribute_base(&method.name);
        match generated {
            "GeneratedAssociationMethods" => Some(
                model
                    .associations
                    .iter()
                    .find(|a| {
                        a.name == base
                            || (a.name.starts_with(base) && a.name.len() <= base.len() + 2)
                    })
                    .map(|a| a.macro_.clone())
                    .unwrap_or_else(|| "association".into()),
            ),
            "GeneratedAttributeMethods" => Some(
                if model.columns.iter().any(|c| c.name == base) {
                    "attribute (schema)"
                } else if model.attribute_aliases.contains_key(base) {
                    "alias_attribute"
                } else if model.attributes.iter().any(|a| a.name == base) {
                    "attribute"
                } else {
                    "attribute_methods"
                }
                .into(),
            ),
            _ => None,
        }
    }
}

/// Strips Rails' attribute/association method affixes:
/// `saved_change_to_title?` → `title`, `comment_ids=` → `comment`.
fn attribute_base(name: &str) -> &str {
    const PREFIXES: &[&str] = &[
        "saved_change_to_",
        "will_save_change_to_",
        "restore_",
        "clear_",
        "reset_",
        "reload_",
        "build_",
        "create_",
    ];
    const SUFFIXES: &[&str] = &[
        "_before_last_save",
        "_previously_changed?",
        "_previously_was",
        "_before_type_cast",
        "_for_database",
        "_in_database",
        "_change_to_be_saved",
        "_came_from_user?",
        "_previous_change",
        "_will_change!",
        "_changed?",
        "_change",
        "_was",
        "_ids=",
        "_ids",
        "_changes",
        "!",
        "?",
        "=",
    ];
    let mut s = name;
    for p in PREFIXES {
        if let Some(rest) = s.strip_prefix(p) {
            s = rest;
            break;
        }
    }
    for suf in SUFFIXES {
        if let Some(rest) = s.strip_suffix(suf) {
            s = rest;
            break;
        }
    }
    s
}

/// "ActiveRecord::Scoping::Named::ClassMethods#scope" → "scope".
fn short_site(site: &str) -> String {
    site.rsplit(['#', '.']).next().unwrap_or(site).to_string()
}

/// "(eval at /abs/file.rb:12)" → ("/abs/file.rb", 12).
fn eval_site(path: &str) -> Option<(&str, u32)> {
    let inner = path.strip_prefix("(eval at ")?.strip_suffix(')')?;
    split_location(inner)
}

struct LineMap {
    starts: Vec<usize>,
}

impl LineMap {
    fn new(src: &[u8]) -> Self {
        let mut starts = vec![0];
        starts.extend(
            src.iter()
                .enumerate()
                .filter(|(_, b)| **b == b'\n')
                .map(|(i, _)| i + 1),
        );
        LineMap { starts }
    }

    fn line(&self, offset: usize) -> u32 {
        self.starts.partition_point(|s| *s <= offset) as u32
    }
}

struct Indexer {
    lines: LineMap,
    index: SourceIndex,
    nesting: Vec<String>,
    /// Depth of `class << self` blocks.
    singleton: usize,
}

impl Indexer {
    fn with_nesting(&mut self, name: &[u8], f: impl FnOnce(&mut Self)) {
        self.nesting
            .push(String::from_utf8_lossy(name).into_owned());
        f(self);
        self.nesting.pop();
    }
}

impl<'pr> Visit<'pr> for Indexer {
    fn visit_class_node(&mut self, node: &ruby_prism::ClassNode<'pr>) {
        self.with_nesting(node.constant_path().location().as_slice(), |v| {
            ruby_prism::visit_class_node(v, node)
        });
    }

    fn visit_module_node(&mut self, node: &ruby_prism::ModuleNode<'pr>) {
        self.with_nesting(node.constant_path().location().as_slice(), |v| {
            ruby_prism::visit_module_node(v, node)
        });
    }

    fn visit_singleton_class_node(&mut self, node: &ruby_prism::SingletonClassNode<'pr>) {
        self.singleton += 1;
        ruby_prism::visit_singleton_class_node(self, node);
        self.singleton -= 1;
    }

    fn visit_def_node(&mut self, node: &ruby_prism::DefNode<'pr>) {
        let loc = node.location();
        let name = String::from_utf8_lossy(node.name().as_slice()).into_owned();
        let first = self.lines.line(loc.start_offset());
        let last = self
            .lines
            .line(loc.end_offset().saturating_sub(1).max(loc.start_offset()));
        let sep = if node.receiver().is_some() || self.singleton > 0 {
            "."
        } else {
            "#"
        };
        let qualified = format!("{}{sep}{name}", self.nesting.join("::"));
        self.index
            .def_spans
            .entry((first, name.clone()))
            .or_insert((loc.start_offset(), loc.end_offset()));
        self.index.defs.entry(first).or_default().push(name);
        self.index.def_ranges.push((first, last, qualified));
        ruby_prism::visit_def_node(self, node);
    }

    fn visit_call_node(&mut self, node: &ruby_prism::CallNode<'pr>) {
        let name = String::from_utf8_lossy(node.name().as_slice()).into_owned();
        let recv_less = node.receiver().is_none();
        let start = self.lines.line(node.location().start_offset());
        self.index
            .call_spans
            .entry(start)
            .or_insert((node.location().start_offset(), node.location().end_offset()));
        let msg = node
            .message_loc()
            .map(|l| self.lines.line(l.start_offset()))
            .unwrap_or(start);
        for line in if msg == start {
            vec![start]
        } else {
            vec![start, msg]
        } {
            self.index
                .calls
                .entry(line)
                .or_default()
                .push((name.clone(), recv_less));
        }
        ruby_prism::visit_call_node(self, node);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::facts::schema::{Association, Column, Gem, Model};

    const APP_SRC: &str = r#"class Article < ApplicationRecord
  has_many :comments, dependent: :destroy
  delegate :name,
    to: :author
  attr_accessor :draft
  define_method(:shout) { title.upcase }
  class_eval "def evaled; end"

  def summary
    body[0, 10]
  end

  private def secret = 1

  class << self
    def recent; end
  end
end
"#;

    const GEM_SRC: &str = r#"module ActiveRecord
  module Scoping
    module Named
      module ClassMethods
        def scope(name, body)
          singleton_class.define_method(name) do |*args|
            body.call(*args)
          end
        end
      end
    end
  end
  module Builder
    def self.define_readers(mixin, name)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}; association(:#{name}).reader; end
      CODE
    end
  end
  included do
    layout -> { false }
  end
end
"#;

    #[test]
    fn index_and_classify_lines() {
        let idx = SourceIndex::parse(APP_SRC.as_bytes());
        assert_eq!(
            classify_line(&idx, 9, "summary", true, false),
            Some(LineOrigin::Def)
        );
        assert_eq!(
            classify_line(&idx, 13, "secret", true, false),
            Some(LineOrigin::Def)
        );
        assert_eq!(
            classify_line(&idx, 16, "recent", true, false),
            Some(LineOrigin::Def)
        );
        assert_eq!(
            classify_line(&idx, 2, "comments", true, false),
            Some(LineOrigin::Call("has_many".into()))
        );
        assert_eq!(
            classify_line(&idx, 3, "name", true, false),
            Some(LineOrigin::Call("delegate".into()))
        );
        assert_eq!(
            classify_line(&idx, 5, "draft=", true, false),
            Some(LineOrigin::Call("attr_accessor".into()))
        );
        assert_eq!(
            classify_line(&idx, 6, "shout", true, false),
            Some(LineOrigin::Call("define_method".into()))
        );
        assert_eq!(
            classify_line(&idx, 7, "evaled", true, true),
            Some(LineOrigin::Call("class_eval".into()))
        );
        // Wrong name at a def line is not a def; blank lines explain nothing.
        assert_eq!(classify_line(&idx, 9, "other", true, false), None);
        assert_eq!(classify_line(&idx, 8, "x", true, false), None);
        assert_eq!(idx.enclosing_def(16), Some("Article.recent"));

        let gem = SourceIndex::parse(GEM_SRC.as_bytes());
        assert_eq!(
            classify_line(&gem, 6, "published", false, false),
            Some(LineOrigin::InsideDef(
                "ActiveRecord::Scoping::Named::ClassMethods#scope".into()
            ))
        );
        assert_eq!(
            classify_line(&gem, 16, "comments", false, false),
            Some(LineOrigin::InsideDef(
                "ActiveRecord::Builder.define_readers".into()
            ))
        );
        assert_eq!(
            classify_line(&gem, 21, "x", false, false),
            Some(LineOrigin::GemCall(Some("layout".into())))
        );
    }

    #[test]
    fn classify_methods_with_boot_facts() {
        let dir = std::env::temp_dir().join(format!("lowrail-origin-{}", std::process::id()));
        let app = dir.join("app");
        let gem = dir.join("gems/activerecord-8.1.4");
        std::fs::create_dir_all(app.join("app/models")).unwrap();
        std::fs::create_dir_all(&gem).unwrap();
        let model_rb = app.join("app/models/article.rb");
        let gem_rb = gem.join("named.rb");
        std::fs::write(&model_rb, APP_SRC).unwrap();
        std::fs::write(&gem_rb, GEM_SRC).unwrap();
        let (m, g) = (model_rb.display().to_string(), gem_rb.display().to_string());

        let method = |name: &str, loc: Option<String>, kind: &str| Method {
            name: name.into(),
            source_location: loc,
            iseq_kind: kind.into(),
            ..Default::default()
        };
        let article = Module {
            name: "Article".into(),
            const_source_location: Some(format!("{m}:1")),
            methods: vec![
                method("summary", Some(format!("{m}:9")), "method"),
                method("name", Some(format!("{m}:3")), "method"),
                method("evaled", Some(format!("(eval at {m}:7):1")), "eval"),
                method("published", Some(format!("{g}:6")), "block"),
                method("hash", None, "cfunc"),
                method("ghost", Some(format!("{m}:8")), "method"),
                method(
                    "autosave_associated_records_for_comments",
                    Some(format!("{g}:16")),
                    "block",
                ),
            ],
            ..Default::default()
        };
        let assoc = Module {
            name: "Article::GeneratedAssociationMethods".into(),
            methods: vec![
                method("comments", Some(format!("{g}:16")), "method"),
                method("comment_ids=", Some(format!("{g}:16")), "method"),
            ],
            ..Default::default()
        };
        let attrs = Module {
            name: "Article::GeneratedAttributeMethods".into(),
            methods: vec![method("title_changed?", Some(format!("{g}:16")), "method")],
            ..Default::default()
        };
        let unrelated = Module {
            name: "ActiveRecord::Base".into(),
            methods: vec![method("save", Some(format!("{g}:5")), "method")],
            ..Default::default()
        };
        let facts = Facts {
            app_root: app.display().to_string(),
            gems: vec![Gem {
                name: "activerecord".into(),
                version: "8.1.4".into(),
                path: gem.display().to_string(),
            }],
            models: vec![Model {
                name: "Article".into(),
                columns: vec![Column {
                    name: "title".into(),
                    ..Default::default()
                }],
                associations: vec![Association {
                    macro_: "has_many".into(),
                    name: "comments".into(),
                    ..Default::default()
                }],
                ..Default::default()
            }],
            modules: vec![article, assoc, attrs, unrelated],
            ..Default::default()
        };

        let mut c = Classifier::new(&facts);
        let got: Vec<(String, Origin)> = c
            .app_relevant()
            .into_iter()
            .map(|o| (format!("{}#{}", o.module.name, o.method.name), o.origin))
            .collect();
        let origin = |k: &str| {
            got.iter()
                .find(|(n, _)| n == k)
                .map(|(_, o)| o.clone())
                .unwrap()
        };
        assert_eq!(got.len(), 10, "{got:#?}");
        assert_eq!(
            origin("Article#summary"),
            Origin::Def {
                file: m.clone(),
                line: 9,
                in_app: true
            }
        );
        assert_eq!(
            origin("Article#name"),
            Origin::GeneratedInApp {
                generator: "delegate".into(),
                file: m.clone(),
                line: 3
            }
        );
        assert_eq!(
            origin("Article#evaled"),
            Origin::GeneratedInApp {
                generator: "class_eval".into(),
                file: m.clone(),
                line: 7
            }
        );
        assert_eq!(
            origin("Article#published"),
            Origin::GeneratedInGem {
                generator: "scope".into(),
                site: "ActiveRecord::Scoping::Named::ClassMethods#scope".into(),
                gem: Some("activerecord".into())
            }
        );
        assert_eq!(
            origin("Article#hash"),
            Origin::NoSource {
                iseq_kind: "cfunc".into()
            }
        );
        assert!(matches!(origin("Article#ghost"), Origin::Unresolved { .. }));
        for k in [
            "Article#autosave_associated_records_for_comments",
            "Article::GeneratedAssociationMethods#comments",
            "Article::GeneratedAssociationMethods#comment_ids=",
        ] {
            assert!(
                matches!(origin(k), Origin::GeneratedInGem { generator, .. } if generator == "has_many"),
                "{k}"
            );
        }
        assert!(matches!(
            origin("Article::GeneratedAttributeMethods#title_changed?"),
            Origin::GeneratedInGem { generator, .. } if generator == "attribute (schema)"
        ));
        std::fs::remove_dir_all(&dir).ok();
    }
}
