//! Small normal-return contracts tied to effective native boot methods.
use super::*;

pub(super) fn lookup(facts: &Facts, receiver: &str, name: &str, singleton: bool) -> Option<Type> {
    let base = receiver.split('[').next()?;
    let (_, method) = resolve(facts, base, name, singleton)?;
    if method.source_location.is_some() || method.iseq_kind != "cfunc" { return None; }
    let result = if singleton && name == "new" && method.owner == "Class"
        && facts.modules.iter().any(|m| m.name == receiver && m.kind == "class") {
        receiver.to_owned()
    } else if !singleton && base == "Array" && method.owner == "Array" && name == "join" {
        "String".into()
    } else if !singleton && base == "Hash" && method.owner == "Hash" && matches!(name, "keys" | "values") {
        let inner = receiver.strip_prefix("Hash[")?.strip_suffix(']')?;
        let mut depth = 0;
        let comma = inner.char_indices().find_map(|(index, c)| {
            match c { '[' | '(' => depth += 1, ']' | ')' => depth -= 1, ',' if depth == 0 => return Some(index), _ => {} }
            None
        })?;
        format!("Array[{}]", if name == "keys" { inner[..comma].trim() } else { inner[comma + 1..].trim() })
    } else { return None; };
    Some(Type::new(result, Source::BootFact,
        format!("{} native {}#{} normal-return contract", facts.ruby_description, method.owner, name)))
}
