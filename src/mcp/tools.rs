use crate::facts::{Classifier, Facts, Origin};
use crate::types::{TypeModel, resolve};
use serde_json::{Value, json};
use std::path::PathBuf;

pub(super) fn list() -> Vec<Value> {
    let string = json!({"type":"string"});
    [
        ("type_of", "Signature/provenance, or a typed fact at slot return, arg:name, ivar:@name", json!({"target":string,"slot":string}), vec!["target"]),
        ("method_facts", "Resolved boot method and its origin/generator", json!({"target":string}), vec!["target"]),
        ("model", "Model columns, associations, callbacks and available validations", json!({"name":string}), vec!["name"]),
        ("routes", "Routes filtered by name/path/controller substrings (AND)", json!({"name":string,"path":string,"controller":string}), vec![]),
        ("lowering_ledger", "Current lowering ledger, including reasons not lowered", json!({}), vec![]),
        ("lowering_status", "Per-method ledger sites: lowered/refused and original reasons; not_recorded is not refused", json!({"target":string}), vec!["target"]),
        ("verify_stats", "Pass and unit hits/fallbacks from the last verify, with build freshness", json!({}), vec![]),
        ("diagnostics", "Source diagnostics and static/observed type conflicts", json!({}), vec![]),
    ].into_iter().map(|(name, description, properties, required)| json!({
        "name":name, "description":description,
        "inputSchema":{"type":"object", "properties":properties, "required":required, "additionalProperties":false},
        "annotations":{"readOnlyHint":true,"destructiveHint":false,"openWorldHint":false}
    })).collect()
}

struct Snapshot {
    bytes: Vec<u8>,
    observed: Option<Vec<u8>>,
    facts: Facts,
    models: Vec<Value>,
    types: TypeModel,
}

pub(super) struct Data {
    app: PathBuf,
    snapshot: Option<Snapshot>,
}

impl Data {
    pub fn new(app: PathBuf) -> Self {
        Self {
            app,
            snapshot: None,
        }
    }

    fn refresh(&mut self) -> Result<&Snapshot, String> {
        let path = self.app.join(".lowrail/facts.json");
        let bytes = std::fs::read(&path).map_err(|e| format!("{}: {e}", path.display()))?;
        let observed = read_optional(&self.app.join(".lowrail/observed.json"))?;
        if self.snapshot.as_ref().is_none_or(|s| s.bytes != bytes || s.observed != observed) {
            let facts: Facts =
                serde_json::from_slice(&bytes).map_err(|e| format!("{}: {e}", path.display()))?;
            if facts.format != 1 {
                return Err(format!("unsupported facts format {}", facts.format));
            }
            // Preserve optional fields (e.g. validations) not yet in Facts.
            #[derive(serde::Deserialize)]
            struct Models {
                #[serde(default)]
                models: Vec<Value>,
            }
            let models: Models = serde_json::from_slice(&bytes).map_err(|e| e.to_string())?;
            let mut types = TypeModel::from_facts(&facts);
            if let Some(bytes) = &observed { types.merge_observed(&facts, bytes)?; }
            self.snapshot = Some(Snapshot {
                bytes,
                observed,
                facts,
                models: models.models,
                types,
            });
        }
        Ok(self.snapshot.as_ref().unwrap())
    }

    pub fn call(&mut self, name: &str, args: &Value) -> Result<Value, String> {
        let schema = list()
            .into_iter()
            .find(|t| t["name"] == name)
            .ok_or("unknown tool")?;
        let args = args.as_object().ok_or("arguments must be an object")?;
        for (key, value) in args {
            if schema["inputSchema"]["properties"].get(key).is_none() || !value.is_string() {
                return Err(format!("unexpected argument or non-string value: {key}"));
            }
        }
        let required = |key: &str| {
            args.get(key)
                .and_then(Value::as_str)
                .ok_or_else(|| format!("{key} is required"))
        };
        if name == "lowering_ledger" {
            let path = self.app.join(".lowrail/ledger.json");
            return match std::fs::read(&path) {
                Ok(bytes) => Ok(
                    json!({"available":true,"ledger":serde_json::from_slice::<Value>(&bytes).map_err(|e| e.to_string())?}),
                ),
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(
                    json!({"available":false,"reason":"ledger.json does not exist; run lowrail build"}),
                ),
                Err(e) => Err(format!("{}: {e}", path.display())),
            };
        }
        if name == "verify_stats" {
            let Some(bytes) = read_optional(&self.app.join(".lowrail/verify/last.json"))? else {
                return Ok(json!({"available":false,"reason":"no last verify report"}));
            };
            let last: Value = serde_json::from_slice(&bytes).map_err(|e| e.to_string())?;
            if last["format"] != 1 || !last["passes"].is_object()
                || !last["report"]["on"]["unit_hits"].is_object()
                || !last["report"]["on"]["unit_fallbacks"].is_object()
            { return Err("invalid or unsupported last verify report".into()); }
            let current: Option<Value> = read_optional(&self.app.join(".lowrail/manifest.json"))?
                .map(|bytes| serde_json::from_slice(&bytes)).transpose().map_err(|e| e.to_string())?;
            return Ok(json!({"available":true,"matches_current_manifest":current.as_ref() == Some(&last["manifest"]),
                "identical":last["identical"],"command":last["command"],"passes":last["passes"],
                "unit_hits":last["report"]["on"]["unit_hits"],
                "unit_fallbacks":last["report"]["on"]["unit_fallbacks"],
                "recorder_overhead":last["recorder_overhead"]}));
        }
        let ledger = if name == "lowering_status" {
            read_optional(&self.app.join(".lowrail/ledger.json"))?
                .map(|bytes| serde_json::from_slice::<Vec<Value>>(&bytes)).transpose().map_err(|e| e.to_string())?
        } else { None };
        let snapshot = self.refresh()?;
        match name {
            "type_of" => {
                let target = required("target")?;
                let sig = snapshot
                    .types
                    .lookup(target)
                    .ok_or_else(|| format!("no type known for {target}"))?;
                if let Some(slot) = args.get("slot").and_then(Value::as_str) {
                    let fact = snapshot.types.fact(target, slot).ok_or("no fact for slot")?;
                    return Ok(json!({"target":target,"slot":slot,"fact":fact,
                        "proven_type":fact.proven_type(),"conflicts":snapshot.types.conflicts.iter()
                            .filter(|c| c.method == target && c.slot == slot).collect::<Vec<_>>()}));
                }
                let id = crate::types::key(&sig.receiver, &sig.method, sig.singleton);
                Ok(json!({"target":target,"signature":sig.signature(),"type":sig,
                    "conflicts":snapshot.types.conflicts.iter().filter(|c| c.method == id).collect::<Vec<_>>()}))
            }
            "lowering_status" => {
                let target = required("target")?;
                let Some(ledger) = ledger else {
                    return Ok(json!({"available":false,"target":target,"status":"not_recorded"}));
                };
                let span = method_span(&snapshot.facts, target);
                let entries: Vec<_> = ledger.iter().filter(|entry| {
                    entry["target"] == target || entry["method"] == target || span.as_ref().is_some_and(|(path, start, end)| {
                        (entry["target"] == path.as_str() || entry["file"] == path.as_str())
                            && entry["line"].as_u64().is_some_and(|line| line >= *start && line <= *end)
                    })
                }).collect();
                let lowered = entries.iter().any(|e| e["outcome"] == "lowered");
                let refused = entries.iter().any(|e| e["outcome"] == "refused");
                let status = match (lowered, refused) {
                    (true, true) => "mixed", (true, false) => "lowered", (false, true) => "refused", _ => "not_recorded"
                };
                Ok(json!({"available":true,"target":target,"status":status,"sites":entries}))
            }
            "method_facts" => {
                let target = required("target")?;
                let (receiver, method, singleton) = if let Some((c, m)) = target.rsplit_once('#') {
                    (c, m, false)
                } else if let Some((c, m)) = target.rsplit_once('.') {
                    (c, m, true)
                } else {
                    return Err("expected Class#method or Class.method".into());
                };
                let (module, method) = resolve(&snapshot.facts, receiver, method, singleton)
                    .ok_or_else(|| format!("no boot method for {target}"))?;
                let origin = Classifier::new(&snapshot.facts).classify(module, method);
                Ok(
                    json!({"target":target,"resolved_module":module.name,"method":method,"origin":origin_json(origin)}),
                )
            }
            "model" => {
                let name = required("name")?;
                let model = snapshot
                    .models
                    .iter()
                    .find(|m| m["name"] == name)
                    .ok_or_else(|| format!("unknown model {name}"))?;
                Ok(
                    json!({"model":model,"validations_available":model.get("validations").is_some()}),
                )
            }
            "routes" => {
                let routes: Vec<_> = snapshot
                    .facts
                    .routes
                    .iter()
                    .filter(|r| {
                        [
                            ("name", r.name.as_deref()),
                            ("path", Some(r.path.as_str())),
                            ("controller", r.controller.as_deref()),
                        ]
                        .iter()
                        .all(|(key, value)| {
                            args.get(*key).is_none_or(|filter| {
                                value.is_some_and(|v| v.contains(filter.as_str().unwrap()))
                            })
                        })
                    })
                    .collect();
                Ok(json!({"routes":routes}))
            }
            "diagnostics" => {
                Ok(json!({"diagnostics":snapshot.types.diagnostics,"conflicts":snapshot.types.conflicts}))
            }
            _ => Err("unknown tool".into()),
        }
    }
}

fn read_optional(path: &std::path::Path) -> Result<Option<Vec<u8>>, String> {
    match std::fs::read(path) {
        Ok(bytes) => Ok(Some(bytes)),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(format!("{}: {e}", path.display())),
    }
}

/// Match the actual def span, never the whole containing file.
fn method_span(facts: &Facts, target: &str) -> Option<(String, u64, u64)> {
    use ruby_prism::Visit;
    let (receiver, name, singleton) = target.rsplit_once('#').map(|(c, m)| (c, m, false))
        .or_else(|| target.rsplit_once('.').map(|(c, m)| (c, m, true)))?;
    let (_, method) = resolve(facts, receiver, name, singleton)?;
    let (path, line) = crate::facts::schema::split_location(method.source_location.as_deref()?)?;
    let source = std::fs::read(path).ok()?;
    let parsed = ruby_prism::parse(&source);
    if parsed.errors().next().is_some() { return None; }
    struct Span<'a> { source: &'a [u8], name: &'a str, line: u64, end: Option<u64> }
    impl<'pr> Visit<'pr> for Span<'_> {
        fn visit_def_node(&mut self, node: &ruby_prism::DefNode<'pr>) {
            let start = self.source[..node.location().start_offset()].iter().filter(|b| **b == b'\n').count() as u64 + 1;
            if start == self.line && node.name().as_slice() == self.name.as_bytes() {
                self.end = Some(self.source[..node.location().end_offset()].iter().filter(|b| **b == b'\n').count() as u64 + 1);
            }
            ruby_prism::visit_def_node(self, node);
        }
    }
    let mut span = Span { source: &source, name: method.def_name(), line: line as u64, end: None };
    span.visit(&parsed.node());
    Some((path.into(), line as u64, span.end?))
}

fn origin_json(origin: Origin) -> Value {
    let category = origin.category();
    let mut value = match origin {
        Origin::NoSource { iseq_kind } => json!({"iseq_kind":iseq_kind}),
        Origin::Def { file, line, in_app } => json!({"file":file,"line":line,"in_app":in_app}),
        Origin::GeneratedInApp {
            generator,
            file,
            line,
        } => json!({"generator":generator,"file":file,"line":line}),
        Origin::GeneratedInGem {
            generator,
            site,
            gem,
        } => json!({"generator":generator,"site":site,"gem":gem}),
        Origin::Template { file } => json!({"file":file}),
        Origin::Unresolved { reason } => json!({"reason":reason}),
    };
    value["category"] = json!(category);
    value
}
