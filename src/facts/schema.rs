//! Serde types for `facts.json` (docs/FORMATS.md). Every field has a
//! default so that a dump from a newer or partial dumper still loads.

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Facts {
    pub format: u32,
    pub ruby_description: String,
    pub rails_version: Option<String>,
    pub app_root: String,
    pub yjit: bool,
    pub gems: Vec<Gem>,
    pub load_path_features: Vec<String>,
    pub models: Vec<Model>,
    pub controllers: Vec<Controller>,
    pub routes: Vec<Route>,
    pub template_config: Option<TemplateConfig>,
    pub templates: Vec<Template>,
    pub module_stats: ModuleStats,
    pub modules: Vec<Module>,
    pub errors: Vec<FactError>,
    pub timings: BTreeMap<String, f64>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Gem {
    pub name: String,
    pub version: String,
    pub path: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct ModuleStats {
    pub named: usize,
    pub anonymous: usize,
    pub anonymous_rooted: usize,
    pub singleton_classes: usize,
    pub methods: usize,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Module {
    pub name: String,
    /// "class" or "module".
    pub kind: String,
    pub superclass: Option<String>,
    pub ancestors: Vec<String>,
    pub singleton_ancestors: Vec<String>,
    pub const_source_location: Option<String>,
    pub methods: Vec<Method>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Method {
    pub name: String,
    pub singleton: bool,
    pub visibility: String,
    pub owner: String,
    pub source_location: Option<String>,
    pub parameters: Vec<Vec<String>>,
    /// method | block | eval | cfunc | attr_reader | attr_writer | none
    pub iseq_kind: String,
    /// Set when the method is an alias (`alias_method`, `alias`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub original_name: Option<String>,
}

impl Method {
    /// The name the body was defined under (differs for aliases).
    pub fn def_name(&self) -> &str {
        self.original_name.as_deref().unwrap_or(&self.name)
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Model {
    pub name: String,
    pub table: String,
    pub primary_key: serde_json::Value,
    pub attribute_methods_defined: bool,
    pub columns: Vec<Column>,
    /// Attributes declared with the attribute API that are not columns.
    pub attributes: Vec<Attribute>,
    /// `alias_attribute` (and Rails' own `id_value`): alias → original.
    pub attribute_aliases: BTreeMap<String, String>,
    pub associations: Vec<Association>,
    pub callbacks: BTreeMap<String, Vec<Callback>>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Column {
    pub name: String,
    #[serde(rename = "type")]
    pub type_: Option<String>,
    pub sql_type: Option<String>,
    pub null: bool,
    pub default: serde_json::Value,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Attribute {
    pub name: String,
    #[serde(rename = "type")]
    pub type_: serde_json::Value,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Association {
    #[serde(rename = "macro")]
    pub macro_: String,
    pub name: String,
    pub class_name: Option<String>,
    pub foreign_key: serde_json::Value,
    pub options: serde_json::Value,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Callback {
    /// before | after | around
    pub kind: String,
    /// Method name, proc source location, or class name of a callback object.
    pub filter: String,
    /// method | proc | object
    pub filter_type: String,
    pub conditions: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Controller {
    pub name: String,
    pub r#abstract: bool,
    pub actions: Vec<String>,
    pub callbacks: Vec<Callback>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Route {
    pub verb: String,
    pub path: String,
    pub name: Option<String>,
    pub controller: Option<String>,
    pub action: Option<String>,
    /// Rack app class for mounts (absent for controller routes).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub app: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub engine: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub internal: Option<bool>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct TemplateConfig {
    /// `ActionView::Template.frozen_string_literal`
    pub frozen_string_literal: bool,
    /// `ActionView::Base.annotate_rendered_view_with_filenames`
    pub annotate_rendered_view_with_filenames: bool,
}

/// A template file under one of the app's view paths.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Template {
    /// Absolute path.
    pub identifier: String,
    /// "articles/index", "articles/_article" (partials keep the underscore).
    pub virtual_path: Option<String>,
    pub format: Option<String>,
    pub variant: Option<String>,
    /// Handler class, e.g. "ActionView::Template::Handlers::ERB".
    pub handler: String,
    pub source_sha256: String,
    /// Handler output (`@handler.call(template, source)`), the body that
    /// `ActionView::Template#compiled_source` wraps into a method.
    pub code: String,
    /// The `locals:` magic comment, if any ("**nil" when empty).
    pub strict_locals: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct FactError {
    pub r#where: String,
    /// "error" or "skipped" (e.g. a model whose table does not exist).
    pub kind: String,
    pub error: String,
}

/// Splits "path:line" (as written by the dumper) into its parts.
pub fn split_location(loc: &str) -> Option<(&str, u32)> {
    let (path, line) = loc.rsplit_once(':')?;
    Some((path, line.parse().ok()?))
}
