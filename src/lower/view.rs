//! View lowering: specializes helper calls inside compiled ERB code.
//!
//! Rails compiles a template to Ruby code like
//! `@output_buffer.append=( link_to "Show", article, class: "x" );`.
//! For a supported call whose arguments are literals, local/instance
//! variables, or route-helper calls, the pass asks the oracle (a booted view
//! context) to evaluate the helper with marker strings in place of the
//! dynamic parts, checks with probe values that each marker is subject to
//! exactly HTML attribute or content escaping, and replaces the call with
//!
//! ```ruby
//! ((::Lowrail.ok?(U, self.class) && <type checks>) ? (<inline>) : (<original call>))
//! ```
//!
//! The replacement keeps the original text verbatim in the fallback branch and
//! puts the specialized branch on the call's first line, so line numbers of
//! the template are unchanged. Guard checks only read variables, so taking the
//! fallback never evaluates an argument twice.

use ruby_prism::Node;
use serde::Serialize;

use super::oracle::Oracle;

const SAMPLE: &str = "<&\\\"'>x";
const SAMPLE_CONTENT: &str = "&lt;&amp;&quot;&#39;&gt;x";

/// A method the specialized code assumes resolves as it did at build time.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, PartialOrd, Ord)]
pub struct Dep {
    /// "@self" for the class of `self` at the call site (checked per class at
    /// runtime), else a constant.
    pub receiver: String,
    pub method: String,
    /// True for `Receiver.method` (a method of the singleton class).
    #[serde(skip_serializing_if = "std::ops::Not::not")]
    pub singleton: bool,
    /// None for an anonymous module (the route set's helper module).
    pub owner: Option<String>,
    pub source_location: Option<String>,
    pub visibility: String,
    /// For a named-route helper: the route it was specialized for.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub route: Option<RouteFact>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, PartialOrd, Ord)]
pub struct RouteFact {
    pub name: String,
    pub spec: String,
    pub parts: Vec<String>,
    /// `route.defaults.inspect`.
    pub defaults: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct Site {
    pub line: usize,
    pub helper: String,
    /// "lowered" or the reason it was not.
    pub outcome: String,
}

#[derive(Debug, Default)]
pub struct Lowered {
    pub code: String,
    pub sites: Vec<Site>,
    pub deps: Vec<Dep>,
}

impl Lowered {
    pub fn lowered_count(&self) -> usize {
        self.sites.iter().filter(|s| s.outcome == "lowered").count()
    }
}

/// Diagnose handler bodies in Action View's method context, without expanding
/// the existing source passes' lowering eligibility (or adding fast-path hits).
pub(super) fn template_parse_refusal(code: &str) -> Site {
    let wrapped = format!("def __lowrail_template__;{code}\nend");
    let result = ruby_prism::parse(wrapped.as_bytes());
    let outcome = match result.errors().next() {
        Some(error) => format!("template source does not parse in method context: {}", error.message()),
        None => "template requires method context; diagnostic only, original handler retained".into(),
    };
    Site { line: 1, helper: "compiled_body".into(), outcome }
}

/// Methods `link_to(name, url_string_or_record, literal_html_options)` runs
/// through for the shapes this pass accepts.
const LINK_TO_VIEW_DEPS: &[&str] = &["link_to", "url_for", "content_tag", "url_target", "convert_options_to_data_attributes", "tag_builder"];
const TAG_BUILDER_DEPS: &[&str] = &["content_tag_string", "tag_options", "tag_option"];

/// `locals` are the names the template may receive as locals (for a partial
/// `_article`: `article`, `article_counter`, ...). They are declared in front
/// of the code so Prism reads them as variables; the emitted guard re-checks
/// `defined?(x) == "local-variable"`, because the same template compiled for
/// another locals set would turn `x` into a method call.
pub fn lower_template(original: &str, locals: &[String], unit: usize, oracle: &mut dyn Oracle) -> Lowered {
    let prefix: String = locals.iter().map(|l| format!("{l} = nil; ")).collect();
    let src = format!("{prefix}{original}");
    let code = src.as_str();
    let result = ruby_prism::parse(code.as_bytes());
    let mut out = Lowered::default();
    if result.errors().next().is_some() {
        return Lowered { code: original.to_string(), sites: vec![template_parse_refusal(code)], deps: vec![] };
    }
    let mut calls = Vec::new();
    collect_appended_calls(&result.node(), &mut calls);

    let mut edits: Vec<(usize, usize, String)> = Vec::new();
    let mut needs_link_to_deps = false;
    let mut route_helpers: Vec<String> = Vec::new();
    for call in calls {
        let start = call.location().start_offset();
        let line = code[..start].matches('\n').count() + 1;
        let helper = name_of(&call);
        match lower_link_to(code, &call, unit, oracle, &mut route_helpers) {
            Ok(replacement) => {
                needs_link_to_deps = true;
                edits.push((start, call.location().end_offset(), replacement));
                out.sites.push(Site { line, helper, outcome: "lowered".into() });
            }
            Err(reason) => out.sites.push(Site { line, helper, outcome: reason }),
        }
    }
    if needs_link_to_deps {
        let mut names: Vec<String> = LINK_TO_VIEW_DEPS.iter().map(|s| s.to_string()).collect();
        names.extend(route_helpers);
        names.sort();
        names.dedup();
        for m in names {
            match resolve(oracle, "self.class", &m) {
                Ok(dep) => out.deps.push(Dep { receiver: "@self".into(), ..dep }),
                Err(e) => {
                    // A dependency we cannot pin down means no lowering at all.
                    out.sites.iter_mut().filter(|s| s.outcome == "lowered").for_each(|s| s.outcome = format!("unresolved dependency {m}: {e}"));
                    return Lowered { code: original.to_string(), sites: out.sites, deps: vec![] };
                }
            }
        }
        for m in TAG_BUILDER_DEPS {
            if let Ok(dep) = resolve(oracle, "::ActionView::Helpers::TagHelper::TagBuilder", m) {
                out.deps.push(Dep { receiver: "ActionView::Helpers::TagHelper::TagBuilder".into(), ..dep });
            }
        }
    }
    let mut lowered = code.to_string();
    edits.sort_by_key(|e| std::cmp::Reverse(e.0));
    for (s, e, r) in edits {
        lowered.replace_range(s..e, &r);
    }
    out.code = lowered[prefix.len()..].to_string();
    out
}

/// Resolves `receiver#method` (an expression evaluating to a module) in the
/// oracle. Owner labels follow the facts dumper: a singleton class owner is
/// `#<Class:Name>`, an anonymous module is None.
pub fn resolve(oracle: &mut dyn Oracle, receiver: &str, method: &str) -> Result<Dep, String> {
    let code = format!(
        "k = ({receiver}); m = k.instance_method(:{method}); o = m.owner; l = o.name || (o.singleton_class? && Module === o.attached_object && o.attached_object.name ? \"#<Class:#{{o.attached_object.name}}>\" : nil); v = k.public_method_defined?(:{method}) ? \"public\" : k.protected_method_defined?(:{method}) ? \"protected\" : \"private\"; JSON.generate([l, m.source_location&.join(\":\"), v])"
    );
    let (s, _) = oracle.eval_string(&code)?;
    let parsed: Vec<Option<String>> = serde_json::from_str(&s).map_err(|e| format!("{e}: {s}"))?;
    Ok(Dep {
        receiver: receiver.into(),
        method: method.into(),
        singleton: false,
        owner: parsed.first().cloned().flatten(),
        source_location: parsed.get(1).cloned().flatten(),
        visibility: parsed.get(2).cloned().flatten().unwrap_or_else(|| "public".into()),
        route: None,
    })
}

/// Calls appended to the output buffer: `@output_buffer.append=( CALL )`.
fn collect_appended_calls<'pr>(node: &Node<'pr>, out: &mut Vec<ruby_prism::CallNode<'pr>>) {
    struct V<'a, 'pr> {
        out: &'a mut Vec<ruby_prism::CallNode<'pr>>,
    }
    impl<'pr> ruby_prism::Visit<'pr> for V<'_, 'pr> {
        fn visit_call_node(&mut self, node: &ruby_prism::CallNode<'pr>) {
            if node.name().as_slice() == b"append=" {
                if let Some(args) = node.arguments() {
                    let args: Vec<_> = args.arguments().iter().collect();
                    if let [arg] = args.as_slice() {
                        let inner = match arg.as_parentheses_node().and_then(|p| p.body()) {
                            Some(body) => body.as_statements_node().and_then(|s| {
                                let b: Vec<_> = s.body().iter().collect();
                                if b.len() == 1 { b[0].as_call_node() } else { None }
                            }),
                            None => arg.as_call_node(),
                        };
                        if let Some(call) = inner {
                            if call.receiver().is_none() && call.block().is_none() && name_of(&call) == "link_to" {
                                self.out.push(call);
                                return;
                            }
                        }
                    }
                }
            }
            ruby_prism::visit_call_node(self, node);
        }
    }
    let mut v = V { out };
    ruby_prism::Visit::visit(&mut v, node);
}

pub(super) fn name_of(call: &ruby_prism::CallNode) -> String {
    String::from_utf8_lossy(call.name().as_slice()).into_owned()
}

pub(super) fn text<'a>(code: &'a str, node: &Node) -> &'a str {
    let l = node.location();
    &code[l.start_offset()..l.end_offset()]
}

/// A value Rails sees as the same constant every time.
fn is_static_literal(node: &Node) -> bool {
    if let Some(s) = node.as_string_node() {
        return s.opening_loc().is_some();
    }
    if node.as_symbol_node().is_some()
        || node.as_integer_node().is_some()
        || node.as_true_node().is_some()
        || node.as_false_node().is_some()
        || node.as_nil_node().is_some()
    {
        return true;
    }
    let elements = if let Some(h) = node.as_hash_node() {
        h.elements()
    } else if let Some(h) = node.as_keyword_hash_node() {
        h.elements()
    } else {
        return false;
    };
    elements.iter().all(|e| match e.as_assoc_node() {
        Some(a) => is_static_literal(&a.key()) && is_static_literal(&a.value()),
        None => false,
    })
}

fn is_variable(node: &Node) -> bool {
    node.as_local_variable_read_node().is_some() || node.as_instance_variable_read_node().is_some()
}

/// `name_path(args)` with only literal or variable arguments.
fn route_helper_call(code: &str, node: &Node) -> Option<String> {
    let call = node.as_call_node()?;
    let name = name_of(&call);
    if call.receiver().is_some() || call.block().is_some() || !name.ends_with("_path") {
        return None;
    }
    if let Some(args) = call.arguments() {
        if !args.arguments().iter().all(|a| is_static_literal(&a) || is_variable(&a)) {
            return None;
        }
    }
    let _ = code;
    Some(name)
}

/// Class a variable holding a record is expected to have, from its name:
/// `article`/`@article` → `Article`. Only a hint; the emitted code checks it.
fn class_hint(var: &str) -> String {
    let base = var.trim_start_matches('@');
    base.split('_').map(|p| {
        let mut c = p.chars();
        c.next().map(|f| f.to_uppercase().collect::<String>() + c.as_str()).unwrap_or_default()
    }).collect()
}

pub fn ruby_str(s: &str) -> String {
    let mut out = String::from("\"");
    for ch in s.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '#' => out.push_str("\\#"),
            '\n' => out.push_str("\\n"),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

enum Hole {
    Content,
    Attr,
}

/// Splits `html` around `markers` (each must occur exactly once).
fn split_markers<'a>(html: &'a str, markers: &[&str]) -> Option<Vec<(usize, &'a str)>> {
    let mut pos: Vec<(usize, usize)> = Vec::new();
    for (i, m) in markers.iter().enumerate() {
        if html.matches(m).count() != 1 {
            return None;
        }
        pos.push((html.find(m)?, i));
    }
    pos.sort();
    let mut parts = Vec::new();
    let mut at = 0;
    for (p, i) in pos {
        parts.push((usize::MAX, &html[at..p]));
        parts.push((i, ""));
        at = p + markers[i].len();
    }
    parts.push((usize::MAX, &html[at..]));
    Some(parts)
}

fn lower_link_to(code: &str, call: &ruby_prism::CallNode, unit: usize, oracle: &mut dyn Oracle, route_helpers: &mut Vec<String>) -> Result<String, String> {
    let args: Vec<Node> = call.arguments().map(|a| a.arguments().iter().collect()).unwrap_or_default();
    if args.len() < 2 || args.len() > 3 {
        return Err("link_to: unsupported arity".into());
    }
    if args.iter().any(|a| a.as_splat_node().is_some() || a.as_block_argument_node().is_some()) {
        return Err("link_to: splat or block argument".into());
    }
    let (name, url) = (&args[0], &args[1]);
    let opts = args.get(2);
    if let Some(o) = opts {
        if !is_static_literal(o) {
            return Err("link_to: html options are not literal".into());
        }
    }

    // Name: literal, or any expression evaluated once into a content hole.
    let name_lit = name.as_string_node().is_some_and(|s| s.opening_loc().is_some());
    let name_src = if name_lit { text(code, name).to_string() } else { "\"LRHNQ\"".into() };

    // URL: literal string, route-helper call, or a record variable.
    let mut cond = Vec::new();
    let url_expr: Option<String>;
    let url_src: String;
    if url.as_string_node().is_some_and(|s| s.opening_loc().is_some()) {
        url_expr = None;
        url_src = text(code, url).to_string();
    } else if let Some(helper) = route_helper_call(code, url) {
        route_helpers.push(helper);
        url_expr = Some(text(code, url).to_string());
        url_src = "\"LRHUQ\"".into();
    } else if is_variable(url) {
        let var = text(code, url).to_string();
        let class = class_hint(&var);
        let route = oracle
            .eval_string(&format!("(defined?(::{class}) && ::{class} < ::ActiveRecord::Base) ? ::{class}.model_name.singular_route_key + \"_path\" : \"\""))
            .map_err(|e| format!("link_to: record class {class}: {e}"))?
            .0;
        if route.is_empty() {
            return Err(format!("link_to: {var} is not known as an Active Record model"));
        }
        // url_for(record) must be exactly the singular route helper.
        let probe = format!(
            "r = ::{class}.instantiate(::{class}.primary_key => 7); (url_for(r) == {route}(r)).to_s"
        );
        if oracle.eval_string(&probe).map(|v| v.0) != Ok("true".into()) {
            return Err(format!("link_to: url_for({class}) is not {route}"));
        }
        route_helpers.push(route.clone());
        if url.as_local_variable_read_node().is_some() {
            cond.push(format!("defined?({var}) == \"local-variable\""));
        }
        cond.push(format!("{var}.instance_of?(::{class}) && {var}.persisted?"));
        url_expr = Some(format!("{route}({var})"));
        url_src = "\"LRHUQ\"".into();
    } else {
        return Err("link_to: url is not a literal, route helper call, or variable".into());
    }

    let opts_src = opts.map(|o| format!(", {}", text(code, o))).unwrap_or_default();
    let call_with = |n: &str, u: &str| format!("link_to({n}, {u}{opts_src})");
    let (html, safe) = oracle.eval_string(&call_with(&name_src, &url_src)).map_err(|e| format!("link_to: oracle: {e}"))?;
    if !safe {
        return Err("link_to: oracle result is not html_safe".into());
    }

    let mut markers: Vec<&str> = Vec::new();
    let mut kinds: Vec<(Hole, String)> = Vec::new();
    if url_expr.is_some() {
        markers.push("LRHUQ");
        kinds.push((Hole::Attr, "__lru".into()));
        if !name_lit {
            // `name || url`: the URL is also the content when name is nil.
            markers.push("LRHNQ");
            kinds.push((Hole::Content, "(__lrn || __lru)".into()));
        }
    } else if !name_lit {
        markers.push("LRHNQ");
        kinds.push((Hole::Content, format!("(__lrn || {})", text(code, url))));
    }
    let parts = split_markers(&html, &markers).ok_or("link_to: marker not found exactly once")?;

    // Probe: each hole must be escaped exactly as attribute/content.
    let probe_name = if name_lit { name_src.clone() } else { format!("\"{SAMPLE}\"") };
    let probe_url = if url_expr.is_some() { format!("\"{SAMPLE}\"") } else { url_src.clone() };
    let (probe_html, _) = oracle.eval_string(&call_with(&probe_name, &probe_url)).map_err(|e| format!("link_to: probe: {e}"))?;
    let mut expected = String::new();
    for (i, s) in &parts {
        if *i == usize::MAX {
            expected.push_str(s);
        } else {
            expected.push_str(match kinds[*i].0 {
                Hole::Attr => "&lt;&amp;&quot;&#39;&gt;x",
                Hole::Content => SAMPLE_CONTENT,
            });
        }
    }
    if probe_html != expected {
        return Err(format!("link_to: escaping probe mismatch: {probe_html} vs {expected}"));
    }

    let mut inline = String::new();
    if !name_lit {
        inline.push_str(&format!("__lrn = {}; ", text(code, name)));
    }
    if let Some(u) = &url_expr {
        inline.push_str(&format!("__lru = {u}; "));
    }
    inline.push('"');
    for (i, s) in &parts {
        if *i == usize::MAX {
            inline.push_str(&ruby_str(s)[1..ruby_str(s).len() - 1]);
        } else {
            let (kind, expr) = &kinds[*i];
            let f = match kind {
                Hole::Attr => "attr",
                Hole::Content => "content",
            };
            inline.push_str(&format!("#{{::Lowrail::Html.{f}({expr})}}"));
        }
    }
    inline.push_str("\".html_safe");
    if inline.contains('\n') {
        return Err("link_to: specialized code would span lines".into());
    }
    let mut guard = format!("::Lowrail.ok?({unit}, self.class)");
    for c in cond {
        guard.push_str(&format!(" && {c}"));
    }
    Ok(format!("(({guard}) ? ({inline}) : ({}))", text(code, &call.as_node())))
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::oracle::Answer;
    use serde_json::Value;

    /// Mimics Rails for the calls the pass makes.
    struct Fake;
    impl Oracle for Fake {
        fn eval(&mut self, code: &str) -> Result<Answer, String> {
            let s = |v: &str, safe| Ok(Answer { value: Value::String(v.into()), class: "String".into(), html_safe: safe });
            if code.contains("singular_route_key") {
                return s(if code.contains("::Article)") { "article_path" } else { "" }, false);
            }
            if code.contains("url_for(r) ==") {
                return s("true", false);
            }
            if code.starts_with("k = ") {
                return s("[\"ActionView::Helpers::UrlHelper\", \"/gems/url_helper.rb:1\", \"public\"]", false);
            }
            if let Some(rest) = code.strip_prefix("link_to(") {
                let esc = |x: &str| x.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;").replace('\'', "&#39;");
                let args: Vec<&str> = rest.trim_end_matches(')').splitn(3, ", ").collect();
                let unq = |x: &str| x.trim_matches('"').replace("\\\"", "\"");
                let class = args.get(2).map(|c| format!(" class=\"{}\"", esc(&unq(c.trim_start_matches("class: "))))).unwrap_or_default();
                return s(&format!("<a{class} href=\"{}\">{}</a>", esc(&unq(args[1])), esc(&unq(args[0]))), true);
            }
            Err(format!("unexpected {code}"))
        }
    }

    #[test]
    fn lowers_link_to_record_and_keeps_lines() {
        let code = "@output_buffer.safe_append='<p>\n'.freeze; @output_buffer.append=( link_to \"Show\", article, class: \"a&b\" ); @output_buffer.safe_append='\n'.freeze;\n@output_buffer";
        let out = lower_template(code, &["article".into()], 3, &mut Fake);
        assert_eq!(out.lowered_count(), 1, "{:?}", out.sites);
        assert_eq!(out.code.matches('\n').count(), code.matches('\n').count());
        assert!(out.code.contains("::Lowrail.ok?(3, self.class) && defined?(article) == \"local-variable\" && article.instance_of?(::Article) && article.persisted?"));
        assert!(out.code.contains(r##"__lru = article_path(article); "<a class=\"a&amp;b\" href=\"#{::Lowrail::Html.attr(__lru)}\">Show</a>".html_safe"##), "{}", out.code);
        assert!(out.code.contains(": (link_to \"Show\", article, class: \"a&b\"))"));
        assert!(out.deps.iter().any(|d| d.method == "article_path" && d.receiver == "@self"));
    }

    #[test]
    fn lowers_dynamic_name_with_route_helper() {
        let code = "@output_buffer.append=( link_to article.title, edit_article_path(article) );";
        let out = lower_template(code, &["article".into()], 0, &mut Fake);
        assert_eq!(out.lowered_count(), 1, "{:?}", out.sites);
        assert!(out.code.contains("__lrn = article.title; __lru = edit_article_path(article);"), "{}", out.code);
        assert!(out.code.contains("#{::Lowrail::Html.content((__lrn || __lru))}"));
    }

    #[test]
    fn refuses_unknown_shapes() {
        let code = "@output_buffer.append=( link_to \"x\", foo.bar, class: dynamic );";
        let out = lower_template(code, &["article".into()], 0, &mut Fake);
        assert_eq!(out.lowered_count(), 0);
        assert_eq!(out.code, code);
        assert_eq!(out.sites[0].outcome, "link_to: html options are not literal");
    }

    #[test]
    fn layout_yield_and_invalid_handler_have_refusals_without_new_lowerings() {
        use super::super::route;
        for (code, reason) in [
            ("@output_buffer.append=(link_to \"Home\", articles_path);\n@output_buffer.append=(yield :sidebar);\n@output_buffer", "template requires method context"),
            ("@output_buffer.append=(link_to \"Home\", articles_path);\n@output_buffer.append=(yield :sidebar);\nif", "template source does not parse"),
        ] {
            let view = lower_template(code, &[], 0, &mut Fake);
            let route = route::lower(code, &route::Mode::Template { locals: &[] }, 0, &mut Fake, &mut route::Cache::default());
            for out in [view, route] {
                assert_eq!(out.code, code);
                assert_eq!(out.lowered_count(), 0);
                assert_eq!(out.sites.len(), 1, "a refused handler must not disappear");
                assert!(out.sites[0].outcome.starts_with(reason), "{:?}", out.sites);
                assert!(out.deps.is_empty());
            }
        }
    }
}
