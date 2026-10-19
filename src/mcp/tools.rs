use crate::facts::{Classifier, Facts, Origin};
use crate::types::{TypeModel, resolve};
use serde_json::{Value, json};
use std::path::PathBuf;

pub(super) fn list() -> Vec<Value> {
    let string = json!({"type":"string"});
    [
        ("type_of", "Signature and provenance for Class#method, Class.method or a route helper", json!({"target":string}), vec!["target"]),
        ("method_facts", "Resolved boot method and its origin/generator", json!({"target":string}), vec!["target"]),
        ("model", "Model columns, associations, callbacks and available validations", json!({"name":string}), vec!["name"]),
        ("routes", "Routes filtered by name/path/controller substrings (AND)", json!({"name":string,"path":string,"controller":string}), vec![]),
        ("lowering_ledger", "Current lowering ledger, including reasons not lowered", json!({}), vec![]),
        ("diagnostics", "Placeholder: source read/parse diagnostics only", json!({}), vec![]),
    ].into_iter().map(|(name, description, properties, required)| json!({
        "name":name, "description":description,
        "inputSchema":{"type":"object", "properties":properties, "required":required, "additionalProperties":false},
        "annotations":{"readOnlyHint":true,"destructiveHint":false,"openWorldHint":false}
    })).collect()
}

struct Snapshot {
    bytes: Vec<u8>,
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
        if self.snapshot.as_ref().is_none_or(|s| s.bytes != bytes) {
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
            let types = TypeModel::from_facts(&facts);
            self.snapshot = Some(Snapshot {
                bytes,
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
        let snapshot = self.refresh()?;
        match name {
            "type_of" => {
                let target = required("target")?;
                let sig = snapshot
                    .types
                    .lookup(target)
                    .ok_or_else(|| format!("no type known for {target}"))?;
                Ok(json!({"target":target,"signature":sig.signature(),"type":sig}))
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
                Ok(json!({"status":"placeholder","diagnostics":snapshot.types.diagnostics}))
            }
            _ => Err("unknown tool".into()),
        }
    }
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
