//! Route-helper specialization: `name_path(args)` for a named route becomes
//! the path built inline from the route's template, under guards.
//!
//! What Rails does (Action Pack 8.1/8.2, `OptimizedUrlHelper#call`) when the
//! route has no requirements and no glob, the call passes exactly one
//! positional argument per required segment, the last argument is not a Hash
//! or `ActionController::Parameters`, and `optimize_routes_generation?` is
//! true (no `default_url_options`):
//!
//! ```text
//! options = url_options.merge(route.defaults)
//! path    = route.format(required_part => arg.to_param, ...)   # raises on nil/""
//! script  = _routes.find_script_name(options)
//! result  = URL.path_for(options.merge(path: path, script_name: script))
//! ```
//!
//! The finishing step retains Rails' dynamic methods, including mounted-engine
//! overrides and URL options. The pass asks the oracle for the
//! path with marker arguments (the template), emits
//!
//! ```ruby
//! ((::Lowrail.ok?(U, self.class)) ? (a0 = ARG0; (<Rails' conditions> && to_param checks) ? finish(path, options, self, false) : name_path(a0)) : (ORIGINAL))
//! ```
//!
//! on the call's first line, and has the oracle run that exact inner
//! expression next to the real helper for awkward arguments in several
//! contexts. Arguments are evaluated once, in order; `url_options`,
//! `optimize_routes_generation?` and `to_param` are called on the fast path
//! just as Rails calls them. When a runtime condition fails after they ran,
//! the helper is called with the already evaluated arguments, so those pure
//! reads run a second time (Rails itself calls `to_param` twice before
//! raising for a nil or empty param).

use std::collections::HashMap;

use ruby_prism::Node;
use serde::Deserialize;

use super::oracle::Oracle;
use super::view::{Dep, Lowered, RouteFact, Site, name_of, resolve, ruby_str};

/// Where the code runs: compiled ERB (one method of a view class; locals
/// declared in front so Prism reads them as variables) or a Ruby file.
pub enum Mode<'a> {
    Template { locals: &'a [String] },
    RubyFile,
}

/// Rails methods whose behavior the fast path inlines. Each becomes a fact,
/// so redefining one (or a Rails upgrade that moves it) disables the units.
const RAILS_DEPS: &[(&str, bool, &[&str])] = &[
    (
        "ActionDispatch::Routing::RouteSet::NamedRouteCollection::UrlHelper::OptimizedUrlHelper",
        false,
        &["call", "optimized_helper", "parameterize_args", "optimize_routes_generation?"],
    ),
    ("ActionDispatch::Journey::Route", false, &["format", "required_parts"]),
    ("ActionDispatch::Journey::Format", false, &["evaluate"]),
    ("ActionDispatch::Http::URL", true, &["url_for", "full_url_for", "build_host_url", "normalize_protocol", "normalize_host", "normalize_port", "named_host?", "secure_protocol"]),
    ("ActionDispatch::Journey::Router::Utils", true, &["escape_segment"]),
    ("ActionDispatch::Journey::Router::Utils::UriEncoder", false, &["escape_segment", "escape"]),
];

/// What the oracle reports for a helper name (Lowrail::OracleRoutes.info).
#[derive(Debug, Clone, Default, Deserialize)]
pub struct Info {
    pub kind: String,
    #[serde(default)]
    pub reason: Option<String>,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub spec: String,
    #[serde(default)]
    pub parts: Vec<String>,
    #[serde(default)]
    pub segment_keys: Vec<String>,
    #[serde(default)]
    pub default_parts: Vec<String>,
    #[serde(default)]
    pub defaults: String,
    #[serde(default)]
    pub option_defaults: Vec<String>,
    #[serde(default)]
    pub optimized: bool,
    #[serde(default)]
    pub owner_ok: Option<bool>,
    #[serde(default)]
    pub source_location: Option<String>,
    #[serde(default)]
    pub visibility: Option<String>,
    #[serde(default)]
    pub template: Option<String>,
    #[serde(default)]
    pub template_error: Option<String>,
}

/// A helper the pass can specialize: the template split into static text and
/// argument holes, already proven by the probes.
#[derive(Debug, Clone)]
pub struct Prepared {
    pub info: Info,
    /// Static text, then hole index, alternating: `Static("/articles/"), Hole(0)`.
    pub pieces: Vec<Piece>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Piece {
    Static(String),
    Hole(usize),
}

/// Oracle answers per helper name, shared across all files of a build.
#[derive(Default)]
pub struct Cache {
    info: HashMap<String, Info>,
    prepared: HashMap<String, Result<Prepared, String>>,
    rails_deps: Option<Result<Vec<Dep>, String>>,
    /// (class, helper) → None when the helper resolves to the route set's
    /// method in that class, else why not.
    resolves: HashMap<(String, String), Option<String>>,
}

pub fn lower(original: &str, mode: &Mode, unit: usize, oracle: &mut dyn Oracle, cache: &mut Cache) -> Lowered {
    let prefix: String = match mode {
        Mode::Template { locals } => locals.iter().map(|l| format!("{l} = nil; ")).collect(),
        Mode::RubyFile => String::new(),
    };
    let src = format!("{prefix}{original}");
    let code = src.as_str();
    let result = ruby_prism::parse(code.as_bytes());
    let unchanged = || Lowered { code: original.to_string(), ..Default::default() };
    if result.errors().next().is_some() {
        return unchanged();
    }
    let template = matches!(mode, Mode::Template { .. });
    let mut found = Vec::new();
    collect(&result.node(), code, template, &mut found);

    let mut out = Lowered::default();
    let mut edits: Vec<(usize, usize, String)> = Vec::new();
    let mut helpers: Vec<(String, Info)> = Vec::new();
    let infos: Vec<Result<Info, String>> = found.iter().map(|c| info_for(oracle, cache, &c.name)).collect();
    for (i, (c, info)) in found.iter().zip(infos).enumerate() {
        let info = match info {
            Ok(info) => info,
            Err(e) => {
                out.sites.push(Site { line: line_of(code, c.start), helper: c.name.clone(), outcome: format!("oracle: {e}") });
                continue;
            }
        };
        if info.kind == "none" {
            continue; // not a route helper (a custom method that ends in _path)
        }
        let line = line_of(code, c.start);
        let nested = found.iter().enumerate().any(|(j, o)| j != i && o.start >= c.start && o.end <= c.end && is_route(cache, &o.name));
        match plan(code, c, &info, nested, oracle, cache) {
            Ok(prepared) => {
                let k = edits.len();
                let replacement = emit(code, c, &prepared, unit, k, template);
                if replacement.matches('\n').count() != text_of(code, c).matches('\n').count() {
                    out.sites.push(Site { line, helper: c.name.clone(), outcome: "specialized code would add lines".into() });
                    continue;
                }
                edits.push((c.start, c.end, replacement));
                helpers.push((c.name.clone(), prepared.info.clone()));
                out.sites.push(Site { line, helper: c.name.clone(), outcome: "lowered".into() });
            }
            Err(reason) => out.sites.push(Site { line, helper: c.name.clone(), outcome: reason }),
        }
    }
    if edits.is_empty() {
        return Lowered { code: original.to_string(), sites: out.sites, deps: vec![] };
    }

    match rails_deps(oracle, cache) {
        Ok(deps) => out.deps.extend(deps),
        Err(e) => {
            out.sites.iter_mut().filter(|s| s.outcome == "lowered").for_each(|s| s.outcome = format!("unresolved Rails dependency: {e}"));
            return Lowered { code: original.to_string(), sites: out.sites, deps: vec![] };
        }
    }
    helpers.sort_by(|a, b| a.0.cmp(&b.0));
    helpers.dedup_by(|a, b| a.0 == b.0);
    for (helper, info) in helpers {
        out.deps.push(Dep {
            receiver: "@self".into(),
            method: helper,
            singleton: false,
            owner: None,
            source_location: info.source_location.clone(),
            visibility: info.visibility.clone().unwrap_or_else(|| "public".into()),
            route: Some(RouteFact { name: info.name.clone(), spec: info.spec.clone(), parts: info.parts.clone(), defaults: info.defaults.clone() }),
        });
    }

    let mut lowered = code.to_string();
    edits.sort_by_key(|e| std::cmp::Reverse(e.0));
    for (s, e, r) in edits {
        lowered.replace_range(s..e, &r);
    }
    // The result must still parse and keep every line where it was.
    let check = ruby_prism::parse(lowered.as_bytes());
    if check.errors().next().is_some() || lowered.matches('\n').count() != code.matches('\n').count() {
        out.sites.iter_mut().filter(|s| s.outcome == "lowered").for_each(|s| s.outcome = "lowered code did not re-parse with the same lines".into());
        return Lowered { code: original.to_string(), sites: out.sites, deps: vec![] };
    }
    out.code = lowered[prefix.len()..].to_string();
    out
}

fn line_of(code: &str, offset: usize) -> usize {
    code[..offset].matches('\n').count() + 1
}

fn text_of<'a>(code: &'a str, c: &Candidate) -> &'a str {
    &code[c.start..c.end]
}

fn is_route(cache: &Cache, name: &str) -> bool {
    cache.info.get(name).is_some_and(|i| i.kind != "none")
}

fn info_for(oracle: &mut dyn Oracle, cache: &mut Cache, helper: &str) -> Result<Info, String> {
    if let Some(i) = cache.info.get(helper) {
        return Ok(i.clone());
    }
    let (json, _) = oracle.eval_string(&format!("JSON.generate(::Lowrail::OracleRoutes.info(self, :{helper}))"))?;
    let info: Info = serde_json::from_str(&json).map_err(|e| format!("{e}: {json}"))?;
    cache.info.insert(helper.to_string(), info.clone());
    Ok(info)
}

fn rails_deps(oracle: &mut dyn Oracle, cache: &mut Cache) -> Result<Vec<Dep>, String> {
    if let Some(r) = &cache.rails_deps {
        return r.clone();
    }
    let mut deps = Vec::new();
    let mut result = Ok(());
    'outer: for (receiver, singleton, methods) in RAILS_DEPS {
        for m in *methods {
            let expr = if *singleton { format!("::{receiver}.singleton_class") } else { format!("::{receiver}") };
            match resolve(oracle, &expr, m) {
                Ok(d) => deps.push(Dep { receiver: receiver.to_string(), singleton: *singleton, ..d }),
                Err(e) => {
                    result = Err(format!("{receiver}{}{m}: {e}", if *singleton { "." } else { "#" }));
                    break 'outer;
                }
            }
        }
    }
    let r = result.map(|_| deps);
    cache.rails_deps = Some(r.clone());
    r
}

/// A receiverless-or-not call whose name ends in `_path` or `_url`.
struct Candidate {
    start: usize,
    end: usize,
    name: String,
    has_receiver: bool,
    /// self is an instance (template, or inside a `def` without receiver).
    instance: bool,
    has_block: bool,
    /// Argument source ranges; Err(reason) when an argument shape is refused.
    args: Result<Vec<(usize, usize)>, String>,
    /// `name` without arguments or parentheses: could be a local variable in
    /// a template whose locals Prism cannot see.
    vcall: bool,
    /// The class whose instance method contains the call, when the innermost
    /// enclosing body is a `class` (not a module, where self can be anything).
    class_name: Option<String>,
}

#[derive(Clone, Copy, PartialEq)]
enum Ctx {
    /// Top level or a class/module body: self is main or a module.
    Body,
    Instance,
    Singleton,
}

fn collect(node: &Node, code: &str, template: bool, out: &mut Vec<Candidate>) {
    struct V<'a> {
        out: &'a mut Vec<Candidate>,
        code: &'a str,
        ctx: Vec<Ctx>,
        /// Enclosing class/module names (None for a module) for class_name.
        names: Vec<(String, bool)>,
    }
    impl V<'_> {
        fn class_name(&self) -> Option<String> {
            let (_, is_class) = self.names.last()?;
            if !is_class {
                return None;
            }
            let mut full = String::new();
            for (n, _) in &self.names {
                if let Some(abs) = n.strip_prefix("::") {
                    full = abs.to_string();
                } else if full.is_empty() {
                    full = n.clone();
                } else {
                    full = format!("{full}::{n}");
                }
            }
            Some(full)
        }
    }
    impl<'pr> ruby_prism::Visit<'pr> for V<'_> {
        fn visit_class_node(&mut self, node: &ruby_prism::ClassNode<'pr>) {
            let l = node.constant_path().location();
            self.names.push((self.code[l.start_offset()..l.end_offset()].to_string(), true));
            self.ctx.push(Ctx::Body);
            ruby_prism::visit_class_node(self, node);
            self.ctx.pop();
            self.names.pop();
        }
        fn visit_module_node(&mut self, node: &ruby_prism::ModuleNode<'pr>) {
            let l = node.constant_path().location();
            self.names.push((self.code[l.start_offset()..l.end_offset()].to_string(), false));
            self.ctx.push(Ctx::Body);
            ruby_prism::visit_module_node(self, node);
            self.ctx.pop();
            self.names.pop();
        }
        fn visit_singleton_class_node(&mut self, node: &ruby_prism::SingletonClassNode<'pr>) {
            self.ctx.push(Ctx::Singleton);
            ruby_prism::visit_singleton_class_node(self, node);
            self.ctx.pop();
        }
        fn visit_def_node(&mut self, node: &ruby_prism::DefNode<'pr>) {
            let inner = if node.receiver().is_some() || *self.ctx.last().unwrap() == Ctx::Singleton { Ctx::Singleton } else { Ctx::Instance };
            self.ctx.push(inner);
            ruby_prism::visit_def_node(self, node);
            self.ctx.pop();
        }
        fn visit_defined_node(&mut self, _node: &ruby_prism::DefinedNode<'pr>) {
            // `defined?(x_path)` asks about the call itself; leave it alone.
        }
        fn visit_call_node(&mut self, node: &ruby_prism::CallNode<'pr>) {
            let name = name_of(node);
            if (name.ends_with("_path") || name.ends_with("_url")) && !node.is_attribute_write() {
                let loc = node.location();
                self.out.push(Candidate {
                    start: loc.start_offset(),
                    end: loc.end_offset(),
                    name: name.clone(),
                    has_receiver: node.receiver().is_some(),
                    instance: *self.ctx.last().unwrap() == Ctx::Instance,
                    has_block: node.block().is_some(),
                    args: arg_ranges(node),
                    vcall: node.is_variable_call(),
                    class_name: self.class_name(),
                });
            }
            ruby_prism::visit_call_node(self, node);
        }
    }
    let mut v = V { out, code, ctx: vec![if template { Ctx::Instance } else { Ctx::Body }], names: vec![] };
    ruby_prism::Visit::visit(&mut v, node);
}

fn arg_ranges(call: &ruby_prism::CallNode) -> Result<Vec<(usize, usize)>, String> {
    let Some(args) = call.arguments() else { return Ok(vec![]) };
    let mut out = Vec::new();
    for a in args.arguments().iter() {
        if a.as_keyword_hash_node().is_some() || a.as_hash_node().is_some() {
            return Err("options hash argument (Rails takes the non-optimized path)".into());
        }
        if a.as_splat_node().is_some() || a.as_forwarding_arguments_node().is_some() || a.as_block_argument_node().is_some() {
            return Err("splat or forwarded arguments".into());
        }
        let l = a.location();
        out.push((l.start_offset(), l.end_offset()));
    }
    Ok(out)
}

fn plan(code: &str, c: &Candidate, info: &Info, nested: bool, oracle: &mut dyn Oracle, cache: &mut Cache) -> Result<Prepared, String> {
    match info.kind.as_str() {
        "path" | "url" => {}
        "custom" | "error" => return Err(info.reason.clone().unwrap_or_else(|| info.kind.clone())),
        other => return Err(format!("unknown helper kind {other}")),
    }
    if c.has_receiver {
        return Err("explicit receiver".into());
    }
    if !c.instance {
        return Err("not inside an instance method (self is a class, module or main)".into());
    }
    if c.has_block {
        return Err("block given".into());
    }
    if let Some(class) = &c.class_name {
        if let Some(why) = resolves_in(oracle, cache, class, &c.name) {
            return Err(why);
        }
    }
    let args = c.args.clone()?;
    if args.len() != info.parts.len() {
        let optional: Vec<_> = info.segment_keys.iter().filter(|p| !info.parts.contains(p)).cloned().collect();
        return Err(format!(
            "{} positional argument(s), route has {} required part(s); default-backed required parts: [{}], optional segments: [{}]; generic argument mapping, recall and script-name resolution before parameter conversion are not modeled",
            args.len(),
            info.parts.len(),
            info.default_parts.join(", "),
            optional.join(", ")
        ));
    }
    if nested {
        return Err("an argument contains another route helper call (the inner one is lowered)".into());
    }
    for (s, e) in &args {
        let t = &code[*s..*e];
        if t.contains('\n') || t.contains("<<") {
            return Err("argument spans lines or contains a heredoc".into());
        }
    }
    prepare(oracle, cache, &c.name, info)
}

/// In a known class, the helper must be the route set's method; otherwise
/// the runtime guard would only ever fall back (e.g. a model's own private
/// `message_path`).
fn resolves_in(oracle: &mut dyn Oracle, cache: &mut Cache, class: &str, helper: &str) -> Option<String> {
    let key = (class.to_string(), helper.to_string());
    if let Some(r) = cache.resolves.get(&key) {
        return r.clone();
    }
    let code = format!(
        "begin; k = ::Object.const_get({}); o = k.instance_method(:{helper}).owner; o.equal?(::Rails.application.routes.named_routes.{module}) ? \"route\" : \"#{{k.name}}#{helper} is defined by #{{o.name || o.inspect}}, not the route set\"; rescue NameError => e; \"#{{e.class}}: #{{e.message[0, 120]}}\"; end",
        ruby_str(class),
        module = if helper.ends_with("_url") { "url_helpers_module" } else { "path_helpers_module" }
    );
    let r = match oracle.eval_string(&code) {
        Ok((s, _)) if s == "route" => None,
        Ok((s, _)) if s.starts_with("NameError: uninitialized constant") => None, // cannot tell; the runtime guard decides
        Ok((s, _)) => Some(s),
        Err(e) => Some(format!("oracle: {e}")),
    };
    cache.resolves.insert(key, r.clone());
    r
}

/// Template split and probes, once per helper.
fn prepare(oracle: &mut dyn Oracle, cache: &mut Cache, helper: &str, info: &Info) -> Result<Prepared, String> {
    if let Some(p) = cache.prepared.get(helper) {
        return p.clone();
    }
    let p = prepare_uncached(oracle, helper, info);
    cache.prepared.insert(helper.to_string(), p.clone());
    p
}

fn prepare_uncached(oracle: &mut dyn Oracle, helper: &str, info: &Info) -> Result<Prepared, String> {
    if !info.optimized {
        return Err("route has requirements or a glob (non-optimized helper)".into());
    }
    if !info.option_defaults.is_empty() {
        return Err(format!("route defaults set url options: {}", info.option_defaults.join(", ")));
    }
    if info.owner_ok != Some(true) {
        return Err("method is not the route set's helper (overridden)".into());
    }
    let template = match (&info.template, &info.template_error) {
        (Some(t), _) => t.clone(),
        (None, Some(e)) => return Err(e.clone()),
        (None, None) => return Err("no template from the oracle".into()),
    };
    let pieces = split_template(&template, info.parts.len())?;
    let temps: Vec<String> = (0..info.parts.len()).map(|i| arg_temp("p", i)).collect();
    let inner = inner_expr(helper, &info.kind, &pieces, "p", &temps);
    let original = format!("{helper}({})", temps.join(", "));
    let temps_lit: Vec<String> = temps.iter().map(|t| ruby_str(t)).collect();
    let code = format!(
        "JSON.generate(::Lowrail::OracleRoutes.probe(::Lowrail::OracleRoutes.contexts(defined?(::ApplicationController) ? ::ApplicationController : ::ActionController::Base) {{ self }}, [{}], {}, {}))",
        temps_lit.join(", "),
        ruby_str(&inner),
        ruby_str(&original)
    );
    let (json, _) = oracle.eval_string(&code).map_err(|e| format!("probe: {e}"))?;
    let v: serde_json::Value = serde_json::from_str(&json).map_err(|e| format!("probe: {e}: {json}"))?;
    if v["ok"] != serde_json::Value::Bool(true) {
        return Err(format!("probe mismatch: {}", v["reason"].as_str().unwrap_or("?")));
    }
    Ok(Prepared { info: info.clone(), pieces })
}

/// `/articles/LRHP0Q/comments/LRHP1Q` → static and hole pieces. Each marker
/// must occur exactly once and the static text must be ASCII (so appending
/// it keeps the encoding Rails' result has).
pub fn split_template(template: &str, holes: usize) -> Result<Vec<Piece>, String> {
    let mut pos: Vec<(usize, usize)> = Vec::new();
    for i in 0..holes {
        let m = format!("LRHP{i}Q");
        if template.matches(&m).count() != 1 {
            return Err(format!("marker {m} not found exactly once in {template:?}"));
        }
        pos.push((template.find(&m).unwrap(), i));
    }
    pos.sort();
    let mut pieces = Vec::new();
    let mut at = 0;
    for (p, i) in pos {
        if p > at {
            pieces.push(Piece::Static(template[at..p].to_string()));
        }
        pieces.push(Piece::Hole(i));
        at = p + format!("LRHP{i}Q").len();
    }
    if at < template.len() {
        pieces.push(Piece::Static(template[at..].to_string()));
    }
    for p in &pieces {
        if let Piece::Static(s) = p {
            if !s.is_ascii() || s.contains("LRHP") {
                return Err(format!("template static text {s:?} is not plain ASCII"));
            }
        }
    }
    Ok(pieces)
}

fn arg_temp(tag: &str, i: usize) -> String {
    format!("__lr{tag}a{i}")
}

/// The expression run after the class guard: Rails' own conditions for the
/// optimized path, then the inline path, else the helper with the evaluated
/// arguments.
pub fn inner_expr(helper: &str, kind: &str, pieces: &[Piece], tag: &str, temps: &[String]) -> String {
    let options = format!("__lr{tag}o");
    let route = helper.strip_suffix("_path").or_else(|| helper.strip_suffix("_url")).unwrap();
    let p = |i: usize| format!("__lr{tag}p{i}");
    let mut conds = Vec::new();
    if let Some(last) = temps.last() {
        conds.push(format!("!(::Hash === {last} || ::ActionController::Parameters === {last})"));
    }
    conds.push("optimize_routes_generation?".to_string());
    // Rails merges options before to_param, but resolves the script name only
    // after formatting the path. Keep that order even for customized methods.
    conds.push(format!("({options} = url_options.merge(::Rails.application.routes.named_routes.get(:{route}).defaults))"));
    for (i, t) in temps.iter().enumerate() {
        conds.push(format!("::String === ({} = {t}.to_param)", p(i)));
        conds.push(format!("!{}.empty?", p(i)));
    }
    let mut path = "+\"\"".to_string();
    for piece in pieces {
        match piece {
            Piece::Static(st) => path.push_str(&format!(" << {}", ruby_str(st))),
            Piece::Hole(i) => path.push_str(&format!(" << ::Lowrail::Routes.seg({})", p(*i))),
        }
    }
    // Old manifests did not guard host normalization. Opt in explicitly so
    // their four-argument finish calls retain Rails' uncached URL strategy.
    let host_cache = if kind == "url" { ", true" } else { "" };
    let fast = format!("::Lowrail::Routes.finish({path}, {options}, self, {}{host_cache})", kind == "url");
    format!("({}) ? ({fast}) : {helper}({})", conds.join(" && "), temps.join(", "))
}

fn emit(code: &str, c: &Candidate, prepared: &Prepared, unit: usize, k: usize, template: bool) -> String {
    let tag = k.to_string();
    let args = c.args.as_ref().expect("planned");
    let temps: Vec<String> = (0..args.len()).map(|i| arg_temp(&tag, i)).collect();
    let mut guard = format!("::Lowrail.ok?({unit}, self.class)");
    if c.vcall && template {
        // In a template the name may be a local variable passed to render
        // (Rails declares locals in a preamble Prism does not see here).
        guard.push_str(&format!(" && defined?({}) == \"method\"", c.name));
    }
    let mut body = String::new();
    for (t, (s, e)) in temps.iter().zip(args) {
        body.push_str(&format!("{t} = {}; ", &code[*s..*e]));
    }
    body.push_str(&inner_expr(&c.name, &prepared.info.kind, &prepared.pieces, &tag, &temps));
    format!("(({guard}) ? ({body}) : ({}))", text_of(code, c))
}

#[cfg(test)]
mod tests {
    use super::super::oracle::Answer;
    use super::*;
    use serde_json::Value;

    /// Answers like a booted real-blog: `articles`, `article`,
    /// `article_comment` routes, `articles_url`, and a custom `logo_path`.
    #[derive(Default)]
    struct Fake {
        probes: Vec<String>,
        mismatch: bool,
    }
    impl Oracle for Fake {
        fn eval(&mut self, code: &str) -> Result<Answer, String> {
            let s = |v: String| Ok(Answer { value: Value::String(v), class: "String".into(), html_safe: false });
            if let Some(rest) = code.strip_prefix("JSON.generate(::Lowrail::OracleRoutes.info(self, :") {
                let helper = rest.trim_end_matches("))");
                let route = |name: &str, spec: &str, parts: &[&str], template: &str| {
                    let kind = if helper.ends_with("_url") { "url" } else { "path" };
                    serde_json::json!({"kind": kind, "name": name, "spec": spec, "parts": parts, "defaults": "{}",
                        "segment_keys": parts.iter().copied().chain(["format"]).collect::<Vec<_>>(),
                        "option_defaults": [], "optimized": true, "owner_ok": true, "source_location": "/rs.rb:334",
                        "visibility": "public", "template": template})
                    .to_string()
                };
                return s(match helper {
                    "articles_path" => route("articles", "/articles(.:format)", &[], "/articles"),
                    "article_path" => route("article", "/articles/:id(.:format)", &["id"], "/articles/LRHP0Q"),
                    "article_comment_path" => route("article_comment", "/articles/:article_id/comments/:id(.:format)", &["article_id", "id"], "/articles/LRHP0Q/comments/LRHP1Q"),
                    "articles_url" => route("articles", "/articles(.:format)", &[], "/articles"),
                    "user_profile_path" => serde_json::json!({"kind": "path", "name": "user_profile", "parts": ["user_id"],
                        "segment_keys": ["user_id", "format"], "default_parts": ["user_id"],
                        "defaults": "{user_id: \"me\"}", "optimized": true, "owner_ok": true}).to_string(),
                    "fresh_article_path" => serde_json::json!({"kind": "custom", "reason": "fresh_article_path: block-backed direct/resolve helper; result-helper and argument/option mapping are not guarded"}).to_string(),
                    _ => r#"{"kind":"none"}"#.into(),
                });
            }
            if code.contains("OracleRoutes.probe(") {
                self.probes.push(code.to_string());
                return s(if self.mismatch { r#"{"ok":false,"reason":"view, args nil: differs"}"#.into() } else { r#"{"ok":true,"runs":9}"#.into() });
            }
            if code.starts_with("k = ") {
                return s(r#"["Some::Owner", "/gems/x.rb:1", "public"]"#.into());
            }
            if code.starts_with("begin; k = ::Object.const_get(") {
                return s(if code.contains("\"Webhook\"") { "Webhook#message_path is defined by Webhook, not the route set".into() } else { "route".into() });
            }
            Err(format!("unexpected {code}"))
        }
    }

    const RB: &str = "class ArticlesController < ApplicationController\n  def destroy\n    redirect_to articles_path, status: :see_other\n  end\n\n  def show\n    @url = article_path(@article)\n    two = article_comment_path(@article,\n      @article.comments.first || \n        @comment)\n  end\n\n  def self.helper\n    articles_path\n  end\n\n  LINK = articles_path\n  def url = articles_url\n  def other = logo_path\n  def opts = article_path(@article, format: :json)\n  def arity = article_path\n  def recv = main_app.articles_path\nend\n";

    #[test]
    fn lowers_ruby_file_sites_and_keeps_lines() {
        let mut fake = Fake::default();
        let out = lower(RB, &Mode::RubyFile, 4, &mut fake, &mut Cache::default());
        let outcome = |line: usize| out.sites.iter().find(|s| s.line == line).map(|s| s.outcome.clone()).unwrap_or_default();
        assert_eq!(out.code.matches('\n').count(), RB.matches('\n').count());
        assert_eq!(outcome(3), "lowered");
        assert_eq!(outcome(7), "lowered");
        assert_eq!(outcome(8), "argument spans lines or contains a heredoc");
        assert!(RB.lines().nth(7).unwrap().contains("two = article_comment_path(@article,"));
        assert!(outcome(14).starts_with("not inside an instance method"));
        assert!(outcome(17).starts_with("not inside an instance method"));
        assert_eq!(outcome(18), "lowered");
        // A _url helper retains Rails' full URL finishing strategy.
        assert!(out.code.contains("::Lowrail::Routes.finish(+\"\" << \"/articles\", __lr2o, self, true, true)"), "{}", out.code);
        assert_eq!(out.sites.iter().filter(|s| s.helper == "logo_path").count(), 0, "custom helpers are not route sites");
        assert!(outcome(20).starts_with("options hash"));
        assert!(outcome(21).starts_with("0 positional argument(s), route has 1"));
        assert_eq!(outcome(22), "explicit receiver");
        // Zero-argument helper: Rails' options merge, then the static path.
        assert!(out.code.contains(
            "::Lowrail::Routes.finish(+\"\" << \"/articles\", __lr0o, self, false)"
        ), "{}", out.code);
        // One argument: evaluated once into a temp, to_param checked, segment escaped.
        assert!(out.code.contains(
            "::Lowrail::Routes.finish(+\"\" << \"/articles/\" << ::Lowrail::Routes.seg(__lr1p0), __lr1o, self, false)"
        ), "{}", out.code);
        let route_deps: Vec<_> = out.deps.iter().filter(|d| d.route.is_some()).map(|d| d.method.clone()).collect();
        assert_eq!(route_deps, vec!["article_path", "articles_path", "articles_url"]);
        assert!(out.deps.iter().all(|d| d.route.is_none() || d.receiver == "@self"));
        assert!(out.deps.iter().all(|d| d.receiver != "ActionDispatch::Routing::RouteSet"), "dynamic route sets are called, not inlined");
        assert!(out.deps.iter().any(|d| d.receiver == "ActionDispatch::Http::URL" && d.singleton && d.method == "normalize_host"));
        // One probe per helper, with the same inner expression shape.
        assert_eq!(fake.probes.len(), 3);
        assert!(fake.probes.iter().any(|p| p.contains("::Lowrail::Routes.finish(+\\\"\\\" << \\\"/articles/\\\" << ::Lowrail::Routes.seg(__lrpp0)")), "{:?}", fake.probes);
    }

    #[test]
    fn emitted_routes_preserve_engine_overrides_options_and_evaluation_order() {
        use std::process::Command;
        if !Command::new("ruby").args(["-e", "require 'active_support'; require 'action_controller'"])
            .status().is_ok_and(|s| s.success()) {
            eprintln!("skipped: Rails gems unavailable");
            return;
        }
        for kind in ["path", "url"] {
            let helper = format!("article_{kind}");
            let expression = inner_expr(&helper, kind,
                &[Piece::Static("/articles/".into()), Piece::Hole(0)], "test", &["arg".into()]);
            let code = format!(r#"
                require "active_support"
                require "action_controller"
                require {runtime:?}
                ROUTES = ActionDispatch::Routing::RouteSet.new
                ROUTES.draw {{ get "/articles/:id", to: "articles#show", as: :article }}
                module Rails
                  def self.application = self
                  def self.routes = ROUTES
                end
                $events = []
                ROUTES.define_singleton_method(:find_script_name) do |o|
                  $events << ["script", o[:path], o[:controller], o[:action]]
                  o[:host] = "engine.example"
                  o[:params] = {{ q: "a b" }}
                  "/mounted"
                end
                OTHER = ActionDispatch::Routing::RouteSet.new
                OTHER.define_singleton_method(:find_script_name) {{ |_| raise "unrelated engine" }}
                class Context
                  include ROUTES.url_helpers
                  def optimize_routes_generation? = true
                  def url_options
                    $events << "options"
                    {{host: "example.org", original_script_name: "/root", trailing_slash: true, anchor: "end"}}
                  end
                end
                class Argument
                  def to_param
                    $events << "param"
                    "a b"
                  end
                end
                ctx = Context.new
                arg = Argument.new
                want = ctx.public_send(:{helper}, arg)
                events = $events.dup
                $events.clear
                have = ctx.instance_eval {{ {expression} }}
                raise [want, have].inspect unless want == have
                raise [events, $events].inspect unless events == $events
                expected = "{host}/root/mounted/articles/a%20b/?q=a+b#end"
                raise have.inspect unless have == expected
                raise events.inspect unless events == ["options", "param", ["script", "/articles/a%20b/", "articles", "show"]]
            "#, runtime = crate::facts::gem_dir().join("lib/lowrail/routes.rb").display().to_string(),
                host = if kind == "url" { "http://engine.example" } else { "" });
            let out = Command::new("ruby").args(["-e", &code]).output().unwrap();
            assert!(out.status.success(), "{}", String::from_utf8_lossy(&out.stderr));
        }
    }

    #[test]
    fn custom_blocks_are_not_treated_as_named_route_aliases() {
        let code = "def x = fresh_article_path(@article)\n";
        let mut fake = Fake::default();
        let out = lower(code, &Mode::RubyFile, 0, &mut fake, &mut Cache::default());
        assert_eq!(out.code, code);
        assert_eq!(out.sites[0].outcome, "fresh_article_path: block-backed direct/resolve helper; result-helper and argument/option mapping are not guarded");
        assert!(out.deps.is_empty());
        assert!(fake.probes.is_empty(), "do not execute an unproven app block to guess an alias");
    }

    #[test]
    fn arity_refusals_distinguish_defaults_optional_segments_and_recall() {
        let code = "def defaults = user_profile_path\ndef recall = article_comment_path(comment)\ndef format = article_path(article, :json)\n";
        let mut fake = Fake::default();
        let out = lower(code, &Mode::RubyFile, 0, &mut fake, &mut Cache::default());
        assert_eq!(out.code, code);
        assert_eq!(out.sites.len(), 3);
        assert!(out.sites[0].outcome.contains("default-backed required parts: [user_id], optional segments: [format]"));
        assert!(out.sites[1].outcome.starts_with("1 positional argument(s), route has 2 required part(s); default-backed required parts: []"));
        assert!(out.sites[2].outcome.starts_with("2 positional argument(s), route has 1 required part(s)"));
        assert!(out.sites.iter().all(|s| s.outcome.contains("script-name resolution before parameter conversion are not modeled")));
        assert!(out.deps.is_empty());
        assert!(fake.probes.is_empty());
    }

    #[test]
    fn template_vcall_checks_for_a_local() {
        let code = "@output_buffer.append=( link_to \"Back\", articles_path, class: \"x\" );\n@output_buffer.append=( article_comment_path(comment.article, comment) );";
        let locals = vec!["comment".to_string()];
        let out = lower(code, &Mode::Template { locals: &locals }, 0, &mut Fake::default(), &mut Cache::default());
        assert_eq!(out.lowered_count(), 2, "{:?}", out.sites);
        assert!(out.code.contains("(::Lowrail.ok?(0, self.class) && defined?(articles_path) == \"method\")"), "{}", out.code);
        assert!(out.code.contains("__lr1a0 = comment.article; __lr1a1 = comment; "), "{}", out.code);
        assert!(out.code.contains("<< \"/articles/\" << ::Lowrail::Routes.seg(__lr1p0) << \"/comments/\" << ::Lowrail::Routes.seg(__lr1p1)"));
        assert!(out.code.ends_with(": (article_comment_path(comment.article, comment))) );"));
        assert!(!out.code.starts_with("comment = nil"));
    }

    #[test]
    fn nested_calls_lower_the_inner_one() {
        let code = "def x\n  article_path(article_path(1))\nend\n";
        let out = lower(code, &Mode::RubyFile, 0, &mut Fake::default(), &mut Cache::default());
        let outcomes: Vec<_> = out.sites.iter().map(|s| s.outcome.as_str()).collect();
        assert_eq!(outcomes, vec!["an argument contains another route helper call (the inner one is lowered)", "lowered"]);
    }

    #[test]
    fn probe_mismatch_refuses_and_leaves_code() {
        let mut fake = Fake { mismatch: true, ..Default::default() };
        let code = "def x = article_path(@a)\n";
        let out = lower(code, &Mode::RubyFile, 0, &mut fake, &mut Cache::default());
        assert_eq!(out.code, code);
        assert_eq!(out.sites[0].outcome, "probe mismatch: view, args nil: differs");
        assert!(out.deps.is_empty());
    }

    #[test]
    fn known_class_must_resolve_to_the_route() {
        let code = "class Webhook < ApplicationRecord\n  def payload = article_path(self)\nend\nmodule Helper\n  def x = article_path(@a)\nend\n";
        let out = lower(code, &Mode::RubyFile, 0, &mut Fake::default(), &mut Cache::default());
        let outcomes: Vec<_> = out.sites.iter().map(|s| s.outcome.as_str()).collect();
        assert_eq!(outcomes, vec!["Webhook#message_path is defined by Webhook, not the route set", "lowered"]);
    }

    #[test]
    fn defined_is_left_alone() {
        let code = "def x = defined?(articles_path) && articles_path\n";
        let out = lower(code, &Mode::RubyFile, 0, &mut Fake::default(), &mut Cache::default());
        assert_eq!(out.lowered_count(), 1);
        assert!(out.code.starts_with("def x = defined?(articles_path) && (("));
    }

    #[test]
    fn splits_templates() {
        assert_eq!(
            split_template("/a/LRHP1Q/b/LRHP0Q", 2).unwrap(),
            vec![Piece::Static("/a/".into()), Piece::Hole(1), Piece::Static("/b/".into()), Piece::Hole(0)]
        );
        assert!(split_template("/a/LRHP0Q/LRHP0Q", 1).is_err());
        assert!(split_template("/caf\u{e9}/LRHP0Q", 1).is_err());
    }
}
