//! Observations annotate static facts; they never participate in inference.
use super::*;
use crate::observe::Observed;

pub(super) fn read(app: &Path) -> Result<Option<Vec<u8>>, String> {
    let path = app.join(".lowrail/observed.json");
    match std::fs::read(&path) {
        Ok(bytes) => Ok(Some(bytes)),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(format!("{}: {e}", path.display())),
    }
}

impl TypeModel {
    pub fn merge_observed(&mut self, facts: &Facts, bytes: &[u8]) -> Result<(), String> {
        let observed: Observed = serde_json::from_slice(bytes).map_err(|e| format!("observed.json: {e}"))?;
        if observed.format != 1 {
            return Err(format!("unsupported observed format {}", observed.format));
        }
        if !facts.app_root.is_empty() && observed.app_root != facts.app_root {
            return Err("observed.json belongs to a different app root".into());
        }
        for sample in observed.types {
            let receiver = if sample.singleton {
                sample.module.strip_prefix("#<Class:").and_then(|s| s.strip_suffix('>'))
                    .unwrap_or(&sample.module)
            } else {
                &sample.module
            };
            if !constant(receiver) {
                self.diagnostics.push(format!("unrepresentable observed receiver {}", sample.module));
                continue;
            }
            let id = key(receiver, &sample.name, sample.singleton);
            let mut conflicts = Vec::new();
            // Keep after-boot definitions visible, even if boot missed them.
            let sig = self.insert(receiver, &sample.name, sample.singleton,
                Type::new("untyped", Source::Observed, "method seen only at runtime"));
            sig.observation = Some(sample.clone());
            let detail = format!("{} calls, capped={}, limit={}; {}", sample.calls,
                sample.saturated, observed.samples_per_method,
                sample.source_location.as_deref().unwrap_or("unknown source"));
            for name in sample.ivars.keys() {
                sig.ivars.entry(name.clone()).or_insert_with(||
                    Type::new("untyped", Source::Observed, "receiver ivar at method exit"));
            }
            let mut slots = vec![("return".to_owned(), &mut sig.return_type, &sample.returns)];
            for p in &mut sig.parameters {
                // rest/keyrest are containers, whereas RBS expects element/value
                // types. Keep these untyped rather than emitting Array as *T.
                if matches!(p.kind.as_str(), "req" | "opt" | "key" | "keyreq")
                    && let Some(counts) = sample.args.get(&p.name)
                {
                    slots.push((format!("arg:{}", p.name), &mut p.ty, counts));
                }
            }
            for (name, ty) in &mut sig.ivars {
                if let Some(counts) = sample.ivars.get(name) {
                    slots.push((format!("ivar:{name}"), ty, counts));
                }
            }
            for (slot, ty, counts) in slots {
                if counts.is_empty() { continue; }
                for (class, count) in counts {
                    *ty.samples.entry(class.clone()).or_default() += count;
                    if ty.name != "untyped" && !compatible(facts, &ty.name, class) {
                        conflicts.push(Conflict { method: id.clone(), slot: slot.clone(),
                            static_type: ty.name.clone(), observed_class: class.clone(), count: *count });
                        // A contradicted body fact is not usable as proof.
                        ty.evidence = Evidence::Static;
                    }
                }
                ty.provenance.push(Provenance { source: Source::Observed, detail: detail.clone() });
                if sample.collection_members.get(&slot).is_some_and(|roles| roles.values().any(|c| !c.is_empty())) {
                    ty.provenance.push(Provenance { source: Source::Observed,
                        detail: "collection member classes: at most 8 entries/value, depth 1; empty containers supply no element evidence; not exhaustive".into() });
                    if let Some(roles) = sample.collection_members.get(&slot) {
                        for (role, counts) in roles {
                            if let Some(expected) = member_contract(&ty.name, role) {
                                for (class, count) in counts {
                                    if expected != "untyped" && !compatible(facts, expected, class) {
                                        conflicts.push(Conflict { method: id.clone(), slot: format!("{slot}:{role}"),
                                            static_type: ty.name.clone(), observed_class: class.clone(), count: *count });
                                        ty.evidence = Evidence::Static;
                                    }
                                }
                            }
                        }
                    }
                }
                if ty.name == "untyped" {
                    let arms: std::collections::BTreeSet<_> = counts.keys().map(|c| {
                        let members = sample.collection_members.get(&slot);
                        match c.as_str() {
                            "Array" => format!("Array[{}]", member_type(facts, members, "Array.element")),
                            "Hash" => format!("Hash[{}, {}]", member_type(facts, members, "Hash.key"),
                                member_type(facts, members, "Hash.value")),
                            _ => class_type(facts, c),
                        }
                    }).collect();
                    ty.name = if arms.contains("untyped") { "untyped".into() }
                        else if arms.len() == 1 { arms.into_iter().next().unwrap() }
                        else { format!("({})", arms.into_iter().collect::<Vec<_>>().join(" | ")) };
                    ty.evidence = Evidence::Observed;
                }
            }
            self.conflicts.extend(conflicts);
        }
        Ok(())
    }
}

// One-level histograms can contradict a direct container member contract, but
// cannot distinguish correlated union arms or prove nested member contracts.
fn member_contract<'a>(ty: &'a str, role: &str) -> Option<&'a str> {
    if role == "Array.element" { return ty.strip_prefix("Array[")?.strip_suffix(']'); }
    let inner = ty.strip_prefix("Hash[")?.strip_suffix(']')?;
    let mut depth = 0;
    for (index, c) in inner.char_indices() {
        match c {
            '[' | '(' => depth += 1,
            ']' | ')' => depth -= 1,
            ',' if depth == 0 => return match role {
                "Hash.key" => Some(inner[..index].trim()),
                "Hash.value" => Some(inner[index + 1..].trim()),
                _ => None,
            },
            _ => {}
        }
    }
    None
}

fn member_type(facts: &Facts, members: Option<&BTreeMap<String, BTreeMap<String, u64>>>, role: &str) -> String {
    let Some(counts) = members.and_then(|m| m.get(role)).filter(|c| !c.is_empty()) else {
        return "untyped".into();
    };
    let arms: std::collections::BTreeSet<_> = counts.keys().map(|c| class_type(facts, c)).collect();
    if arms.contains("untyped") { "untyped".into() }
    else if arms.len() == 1 { arms.into_iter().next().unwrap() }
    else { format!("({})", arms.into_iter().collect::<Vec<_>>().join(" | ")) }
}

pub(super) fn constant(name: &str) -> bool {
    !name.is_empty() && name.split("::").all(|part| {
        part.as_bytes().first().is_some_and(u8::is_ascii_uppercase)
            && part.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_')
    })
}

fn class_type(facts: &Facts, class: &str) -> String {
    match class {
        "NilClass" => "nil".into(),
        "TrueClass" | "FalseClass" => "bool".into(),
        "Array" => "Array[untyped]".into(),
        "Hash" => "Hash[untyped, untyped]".into(),
        // Class-only samples reveal neither container elements nor the
        // receiver type parameter of NoMethodError in core RBS.
        "Set" | "Thread::Queue" | "Range" | "NoMethodError" => format!("{class}[untyped]"),
        _ => {
            for (suffix, base) in [("::ActiveRecord_Relation", "ActiveRecord::Relation"),
                ("::ActiveRecord_Associations_CollectionProxy", "ActiveRecord::Associations::CollectionProxy")]
            {
                if let Some(model) = class.strip_suffix(suffix)
                    && facts.models.iter().any(|m| m.name == model)
                {
                    return format!("{base}[{model}]");
                }
            }
            if constant(class) { class.into() } else { "untyped".into() }
        }
    }
}

fn compatible(facts: &Facts, static_type: &str, class: &str) -> bool {
    if static_type.ends_with('?') && class == "NilClass" { return true; }
    let ty = static_type.trim_end_matches('?');
    let ty = if ty.starts_with('(') && ty.ends_with(')') { &ty[1..ty.len()-1] } else { ty };
    let mut depth = 0;
    for (i, c) in ty.char_indices() {
        match c {
            '(' | '[' => depth += 1,
            ')' | ']' => depth -= 1,
            '|' if depth == 0 => return compatible(facts, ty[..i].trim(), class)
                || compatible(facts, ty[i+1..].trim(), class),
            _ => {}
        }
    }
    let ty = ty.trim_start_matches("::");
    let base = ty.split('[').next().unwrap_or(ty);
    // Array/Hash samples do not describe their elements. Keep model-specific
    // relation identities, whose observed class does carry the model name.
    let container = matches!(base, "Array" | "Hash");
    let observed = class_type(facts, class);
    let expected = if container { base } else { ty };
    let observed = if container { observed.split('[').next().unwrap_or(&observed) } else { &observed };
    expected == observed
        || (ty == "true" && class == "TrueClass") || (ty == "false" && class == "FalseClass")
        || facts.modules.iter().any(|m| m.name == class && m.ancestors.iter().any(|a| a == expected))
}
