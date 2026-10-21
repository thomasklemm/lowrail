//! Narrow purity certificates, not a heuristic that arbitrary Ruby is pure.
//! Only audited URI/string-digest intrinsics are certified. Every argument stays
//! a runtime key; no request-dependent helper/resolver is bypassed.
use ruby_prism::Visit;
use serde_json::Value;

use super::oracle::Oracle;
use super::view::{Site, name_of, ruby_str};

pub struct Lowered {
    pub code: String,
    pub sites: Vec<Site>,
    pub certificate: Option<Value>,
}

#[derive(Clone, Copy)]
pub enum Intrinsic { UriJoin, Sha256 }

impl Intrinsic {
    fn spec(self) -> (&'static str, &'static str, usize, &'static str, &'static str) {
        match self {
            Self::UriJoin => ("URI", "join", 2, "join", "build"),
            Self::Sha256 => ("Digest::SHA256", "base64digest", 1, "digest", "digest"),
        }
    }
}

pub fn lower(code: &str, id: usize, oracle: &mut dyn Oracle, certificate: &mut Option<Result<Value, String>>, intrinsic: Intrinsic, parser: &crate::parser::Parser) -> Lowered {
    struct V<'a> { code: &'a str, id: usize, intrinsic: Intrinsic, refined: bool, calls: Vec<(usize, usize, usize, String)>, sites: Vec<Site> }
    impl<'pr> Visit<'pr> for V<'_> {
        fn visit_defined_node(&mut self, _: &ruby_prism::DefinedNode<'pr>) {}
        fn visit_def_node(&mut self, n: &ruby_prism::DefNode<'pr>) {
            let before = self.calls.len() + self.sites.len();
            ruby_prism::visit_def_node(self, n);
            if self.calls.len() + self.sites.len() > before {
                self.sites.push(Site {
                    line: 1 + self.code[..n.location().start() as usize].bytes().filter(|b| *b == b'\n').count(),
                    helper: String::from_utf8_lossy(n.name().as_slice()).into_owned(),
                    outcome: "whole method lacks a purity certificate; only independently certified expressions may be memoized".into(),
                });
            }
        }
        fn visit_call_node(&mut self, n: &ruby_prism::CallNode<'pr>) {
            let name = name_of(n);
            if matches!(name.as_str(), "using" | "send" | "__send__" | "public_send" | "eval" | "module_eval" | "class_eval") {
                self.refined = true; // cannot prove absence of caller-local refinement activation
            }
            let receiver = n.receiver().map(|r| {
                let l = r.location(); &self.code[l.start() as usize..l.end() as usize]
            });
            let line = 1 + self.code[..n.location().start() as usize].bytes().filter(|b| *b == b'\n').count();
            let (target, method, arity, runtime, _) = self.intrinsic.spec();
            let helper = format!("{target}.{method}");
            if name == method && receiver.is_some_and(|r| r.trim_start_matches("::") == target) {
                let args: Vec<_> = n.arguments().map(|a| a.arguments().iter().collect()).unwrap_or_default();
                let reason = if n.block().is_some() || n.is_safe_navigation() { Some("block or safe navigation") }
                    else if args.len() != arity { Some("requires the certified number of positional runtime keys") }
                    else if args.iter().any(|a| a.as_splat_node().is_some() || a.as_keyword_hash_node().is_some() || a.as_forwarding_arguments_node().is_some()) { Some("splat/keyword/forwarded arguments") }
                    else if n.location().as_slice().contains(&b'\n') { Some("multiline call (line preservation)") }
                    else { None };
                if let Some(reason) = reason {
                    self.sites.push(Site { line, helper, outcome: reason.into() });
                } else {
                    let first = args[0].location().start() as usize;
                    let last = args[arity - 1].location().end() as usize;
                    let params = if arity == 2 { "__lrm_b, __lrm_u" } else { "__lrm_b" };
                    self.calls.push((n.location().start() as usize, n.location().end() as usize, line,
                        format!("::Lowrail::Memo.{runtime}({}, {}, {}) {{ |__lrm_r, {params}| __lrm_r.{method}({params}) }}", self.id, receiver.unwrap(), &self.code[first..last])));
                }
            } else if matches!(self.intrinsic, Intrinsic::UriJoin) && (matches!(name.as_str(), "digest" | "hexdigest" | "to_json") ||
                (name == "base64digest" && !receiver.is_some_and(|r| r.trim_start_matches("::") == "Digest::SHA256")) ||
                (name == "parse" && matches!(receiver, Some("JSON" | "::JSON")))) {
                self.sites.push(Site { line, helper: name, outcome: "no purity certificate for the whole call; resolver, file, configuration or mutation effects remain in the original".into() });
            } else if matches!(self.intrinsic, Intrinsic::UriJoin) && name == "bind_controller" {
                self.sites.push(Site { line, helper: name, outcome: "request-bound controller and fresh mutable configuration; no boot-fixed result certificate".into() });
            }
            ruby_prism::visit_call_node(self, n);
        }
    }
    let parsed = parser.parse(code.as_bytes());
    let (target, method, _, _, builder) = intrinsic.spec();
    let helper = format!("{target}.{method}");
    let mut v = V { code, id, intrinsic, refined: false, calls: vec![], sites: vec![] };
    if parsed.errors().next().is_none() { v.visit(&parsed.node()); }
    if v.calls.is_empty() { return Lowered { code: code.into(), sites: v.sites, certificate: None }; }
    if v.refined {
        v.sites.extend(v.calls.iter().map(|(_, _, line, _)| Site {
            line: *line, helper: helper.clone(), outcome: "compilation unit may activate refinements dynamically".into(),
        }));
        return Lowered { code: code.into(), sites: v.sites, certificate: None };
    }
    let cert = certificate.get_or_insert_with(|| {
        let path = crate::facts::gem_dir().join("lib/lowrail/memo_facts.rb");
        let (s, _) = oracle.eval_string(&format!("require {}; ::Lowrail::MemoFacts.{builder}.to_json", ruby_str(&path.display().to_string())))?;
        let data: Value = serde_json::from_str(&s).map_err(|e| e.to_string())?;
        if let Some(reason) = data["decline"].as_str() { Err(reason.into()) } else { Ok(data) }
    }).clone();
    let mut output = code.to_string();
    v.calls.sort_by_key(|c| c.0);
    for (start, end, line, replacement) in v.calls.iter().rev() {
        let nested = v.calls.iter().any(|(s, e, _, _)| s > start && e <= end);
        let reason = if nested { "nested memo expression".to_string() }
            else { cert.as_ref().err().cloned().unwrap_or_else(|| "lowered".into()) };
        if reason == "lowered" { output.replace_range(*start..*end, replacement); }
        v.sites.push(Site { line: *line, helper: helper.clone(), outcome: reason });
    }
    Lowered { code: output, sites: v.sites, certificate: cert.ok() }
}

#[cfg(test)]
mod tests {
    use super::*;
    struct NoOracle;
    impl Oracle for NoOracle {
        fn eval(&mut self, _: &str) -> Result<super::super::oracle::Answer, String> { panic!("unexpected oracle call") }
    }

    #[test]
    fn expressions_keep_evaluation_order_lines_and_uncertified_calls() {
        let parser = crate::parser::Parser::for_runtime("4.0.7").unwrap();
        let source = "def locations; URI.join(base(), url()); end\nURI.join(URI.join(a, b), c)\nURI.join(a, *b)\ndefined?(URI.join(a, b))\nURI.join(a, '{ID}')\n";
        let mut cert = Some(Ok(serde_json::json!({"facts": []})));
        let result = lower(source, 17, &mut NoOracle, &mut cert, Intrinsic::UriJoin, &parser);
        assert!(result.code.starts_with("def locations; ::Lowrail::Memo.join(17, URI, base(), url()) { |__lrm_r, __lrm_b, __lrm_u| __lrm_r.join(__lrm_b, __lrm_u) }; end\n"));
        assert!(result.code.contains("URI.join(::Lowrail::Memo.join(17, URI, a, b) { |__lrm_r, __lrm_b, __lrm_u| __lrm_r.join(__lrm_b, __lrm_u) }, c)"));
        assert!(result.code.contains("URI.join(a, *b)\ndefined?(URI.join(a, b))"));
        assert!(result.code.contains("::Lowrail::Memo.join(17, URI, a, '{ID}')"));
        assert_eq!(result.code.lines().count(), source.lines().count());
        assert!(parser.parse(result.code.as_bytes()).errors().next().is_none());
        let refined = "using CustomURI; URI.join(a, b)";
        assert_eq!(lower(refined, 0, &mut NoOracle, &mut None, Intrinsic::UriJoin, &parser).code, refined);
        let digest = lower("Digest::SHA256.base64digest(input())", 18, &mut NoOracle, &mut cert, Intrinsic::Sha256, &parser);
        assert_eq!(digest.code, "::Lowrail::Memo.digest(18, Digest::SHA256, input()) { |__lrm_r, __lrm_b| __lrm_r.base64digest(__lrm_b) }");
    }

    #[test]
    fn public_inertia_vite_fixture_is_refused_not_assumed_pure() {
        let parser = crate::parser::Parser::for_runtime("4.0.7").unwrap();
        for source in [include_str!("../../tests/fixtures/memo/inertia_version.rb"), include_str!("../../tests/fixtures/memo/inertia_eager_version.rb")] {
            let result = lower(source, 0, &mut NoOracle, &mut None, Intrinsic::UriJoin, &parser);
            assert_eq!(result.code, source);
            assert!(result.certificate.is_none());
            assert!(result.sites.iter().any(|s| s.helper == "digest" && s.outcome.contains("no purity certificate")));
        }
        let binding = "configuration.bind_controller(controller)";
        let result = lower(binding, 0, &mut NoOracle, &mut None, Intrinsic::UriJoin, &parser);
        assert_eq!(result.code, binding);
        assert!(result.sites.iter().any(|s| s.outcome.contains("request-bound controller")));
    }
}
