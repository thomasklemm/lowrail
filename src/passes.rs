//! Build-time pass registry. Order is semantic: link_to before route/path;
//! runtime passes retain their former digest/preload/instantiate/plans order.

use std::collections::BTreeSet;

use crate::lower::memo::Intrinsic;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind { Source, Runtime }

#[derive(Clone, Copy)]
pub enum Builder {
    View,
    Route,
    Memo(Intrinsic),
    Runtime { file: &'static str, module: &'static str },
}

pub struct Pass {
    pub name: &'static str,
    pub kind: Kind,
    pub default: bool,
    pub builder: Builder,
    pub alias: &'static str,
}

pub const REGISTRY: &[Pass] = &[
    Pass { name: "view/link_to", kind: Kind::Source, default: true, builder: Builder::View, alias: "link_to" },
    Pass { name: "route/path", kind: Kind::Source, default: true, builder: Builder::Route, alias: "path" },
    Pass { name: "memo/uri_join", kind: Kind::Source, default: false, builder: Builder::Memo(Intrinsic::UriJoin), alias: "uri_join" },
    Pass { name: "memo/sha256", kind: Kind::Source, default: false, builder: Builder::Memo(Intrinsic::Sha256), alias: "sha256" },
    Pass { name: "digest/file_memo", kind: Kind::Runtime, default: false, builder: Builder::Runtime { file: "digest_memo_build", module: "DigestMemoBuild" }, alias: "digest_memo" },
    Pass { name: "active_record/preload_plans", kind: Kind::Runtime, default: false, builder: Builder::Runtime { file: "preload_build", module: "PreloadBuild" }, alias: "preload_plans" },
    Pass { name: "active_record/instantiate", kind: Kind::Runtime, default: false, builder: Builder::Runtime { file: "ar_instantiate_build", module: "ARInstantiateBuild" }, alias: "ar_instantiate" },
    Pass { name: "active_record/ar_plans", kind: Kind::Runtime, default: false, builder: Builder::Runtime { file: "ar_plan_build", module: "ARPlanBuild" }, alias: "ar_plans" },
    Pass { name: "inertia/config_bind", kind: Kind::Runtime, default: false, builder: Builder::Runtime { file: "inertia_config_build", module: "InertiaConfigBuild" }, alias: "inertia_config" },
];

pub struct Selection(BTreeSet<&'static str>);

impl Default for Selection {
    fn default() -> Self {
        Self(REGISTRY.iter().filter(|p| p.default).map(|p| p.name).collect())
    }
}

impl Selection {
    pub fn parse(list: &str) -> Result<Self, String> {
        let mut items = list.split(',');
        if items.next() != Some("default") {
            return Err("--passes must start with default, followed by +name/-name".into());
        }
        let mut selected = Self::default();
        for item in items {
            let (enabled, name) = match item.as_bytes().first() {
                Some(b'+') => (true, &item[1..]),
                Some(b'-') => (false, &item[1..]),
                _ => return Err(format!("expected +name or -name in --passes: {item}")),
            };
            selected.set(name, enabled)?;
        }
        Ok(selected)
    }

    pub fn set(&mut self, name: &str, enabled: bool) -> Result<(), String> {
        let matches: Vec<_> = REGISTRY.iter().filter(|p| p.name == name || p.alias == name || (name == "memo" && p.name.starts_with("memo/"))).collect();
        if matches.is_empty() { return Err(format!("unknown pass {name}")); }
        for pass in matches {
            if enabled { self.0.insert(pass.name); } else { self.0.remove(pass.name); }
        }
        Ok(())
    }

    pub fn contains(&self, name: &str) -> bool { self.0.contains(name) }

    pub fn iter(&self) -> impl Iterator<Item = &'static Pass> + '_ {
        REGISTRY.iter().filter(|p| self.contains(p.name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn selection_defaults_aliases_groups_and_last_modifier_wins() {
        let names = |s: Selection| s.iter().map(|p| p.name).collect::<Vec<_>>();
        assert_eq!(names(Selection::parse("default").unwrap()), ["view/link_to", "route/path"]);
        assert_eq!(names(Selection::parse("default,+ar_instantiate,-view/link_to,+memo,-memo/sha256").unwrap()),
            ["route/path", "memo/uri_join", "active_record/instantiate"]);
        assert_eq!(names(Selection::parse("default,-path,+path,+digest/file_memo,-digest_memo").unwrap()), ["view/link_to", "route/path"]);
        let mut aliases = Selection::default();
        for name in ["memo", "preload_plans", "ar_instantiate", "ar_plans", "digest_memo", "inertia_config"] { aliases.set(name, true).unwrap(); }
        assert_eq!(names(aliases), REGISTRY.iter().map(|p| p.name).collect::<Vec<_>>());
        assert!(Selection::parse("default,-view/link_to,-route/path").unwrap().iter().next().is_none());
    }

    #[test]
    fn selection_rejects_typos_and_malformed_lists() {
        for bad in ["", "all", "+memo", "default,", "default,memo", "default,+", "default,+typo", "default,-typo", "default,default"] {
            assert!(Selection::parse(bad).is_err(), "accepted {bad}");
        }
    }
}
