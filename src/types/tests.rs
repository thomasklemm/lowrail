use super::*;
use serde_json::json;

#[test]
fn unknown_values_do_not_hide_a_known_tail_or_container_but_control_flow_does() {
    let dir = std::env::temp_dir().join(format!("lowrail-type-values-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let file = dir.join("example.rb");
    let bodies = [
        ("tail", "external; 7", "Integer"),
        ("array", "['hello', 7]", "Array[(Integer | String)]"),
        ("hash", "{ label: 'hello', count: 7 }", "Hash[Symbol, (Integer | String)]"),
        ("unknown_element", "[external]", "Array[untyped]"),
        ("branches", "if external; 'yes'; else; 7; end", "(Integer | String)"),
        ("missing_branch", "7 unless external", "(Integer | nil)"),
        ("branch_locals", "if external; value = 7; else; value = 'yes'; end; value", "(Integer | String)"),
        ("nested_union", "if external; if other; 7; else; 'yes'; end; else; 7; end", "(Integer | String)"),
        ("nested_nil", "if external; 'yes'; elsif other; 'no'; end", "(String | nil)"),
        ("container_union", "if external; ['yes', 7]; else; [false]; end", "(Array[(Integer | String)] | Array[bool])"),
        ("nullable", "if external; text; else; nil; end", "String?"),
        ("nullable_array", "[text]", "Array[String?]"),
        ("datetime_array", "[created_at]", "Array[(Time | ActiveSupport::TimeWithZone)?]"),
        ("datetime_both", "if external; created_at; else; created_at; end", "(Time | ActiveSupport::TimeWithZone)?"),
        ("datetime_union", "if external; created_at; else; 'yes'; end", "((Time | ActiveSupport::TimeWithZone)? | String)"),
        ("unknown_branch", "if external; 7; else; other; end", "untyped"),
        ("interpolation", r#""value #{external}""#, "String"),
        ("interpolation_escape", r##""#{external ? (return 7) : 'ok'}""##, "untyped"),
        ("interpolation_mutation", r##"value = 7; "#{object}"; value"##, "untyped"),
        ("hash_mutation", "value = 7; { external => 1 }; value", "untyped"),
        ("autoload_mutation", "value = 7; Other.new; value", "untyped"),
        ("early", "[external ? (return 7) : 'ok']; 'tail'", "untyped"),
        ("nested_early", "{ value: helper(external ? (return 7) : 'ok') }; 'tail'", "untyped"),
        ("block", "external { return 7 }; 'tail'", "untyped"),
        ("stale_ivar", "@value = 7; external; @value", "untyped"),
        ("stale_local", "value = 7; external(binding); value", "untyped"),
    ];
    let source = bodies.iter().map(|(name, body, _)| format!("def {name}; {body}; end\n")).collect::<String>();
    let parser = crate::parser::Parser::for_runtime("4.0.7").unwrap();
    assert!(parser.parse(source.as_bytes()).errors().next().is_none());
    std::fs::write(&file, source).unwrap();
    let methods: Vec<_> = bodies.iter().enumerate().map(|(i, (name, _, _))|
        json!({"name":name,"source_location":format!("{}:{}",file.display(),i+1)})).collect();
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,"ruby_description":"ruby 4.0.7",
        "models":[{"name":"Example","columns":[{"name":"text","type":"string"},
            {"name":"created_at","type":"datetime"}]}],
        "modules":[{"name":"Example","kind":"class","methods":methods}]})).unwrap();
    let model = TypeModel::from_facts(&facts).unwrap();
    for (name, _, expected) in bodies {
        let ty = model.fact(&format!("Example#{name}"), "return").unwrap();
        assert_eq!(ty.name, expected, "{name}");
        assert_eq!(ty.proven_type(), None, "{name} is not a call/context proof");
    }
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn coverage_counts_return_and_argument_slots_not_samples_or_ivars() {
    let dir = std::env::temp_dir().join(format!("lowrail-type-coverage-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let file = dir.join("example.rb");
    std::fs::write(&file, "class Example < Struct\n def proven = 7\n def inferred = proven\n def sampled(value); external(value); end\n def unknown; external; end\nend\n").unwrap();
    let methods: Vec<_> = [("proven",2),("inferred",3),("sampled",4),("unknown",5)].into_iter()
        .map(|(name,line)| json!({"name":name,"source_location":format!("{}:{line}",file.display()),
            "parameters":if name == "sampled" { json!([["req","value"]]) } else { json!([]) }})).collect();
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,"ruby_description":"ruby 4.0.7",
        "modules":[{"name":"Example","kind":"class","superclass":"Struct","methods":methods}]})).unwrap();
    let mut model = TypeModel::from_facts(&facts).unwrap();
    model.merge_observed(&facts, json!({"format":1,"app_root":dir,"types":[
        {"module":"Example","name":"sampled","calls":3,"returns":{"String":3},
            "args":{"value":{"Symbol":3}},"ivars":{"@extra":{"Integer":3}}}
    ]}).to_string().as_bytes()).unwrap();
    let expected = json!({"proven":1,"static":1,"observed":2,"unknown":1});
    assert_eq!(model.typed_facts()["coverage"], expected);
    let export = serde_json::to_value(model.export_rbs(&facts)).unwrap();
    assert_eq!(export["coverage"], expected);
    assert!(export["files"]["app.rbs"].as_str().unwrap().contains("class Example < ::Struct[untyped]"));
    assert!(!export["files"]["app.rbs"].as_str().unwrap().contains("class Struct\n"));
    let comment = export["files"]["app.rbs"].as_str().unwrap().lines()
        .find_map(|line| line.strip_prefix("# lowrail coverage: ")).unwrap();
    assert_eq!(serde_json::from_str::<serde_json::Value>(comment).unwrap(), expected);
    assert_eq!(TypeModel::default().typed_facts()["coverage"],
        json!({"proven":0,"static":0,"observed":0,"unknown":0}));
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn schema_nullability_associations_routes_and_roles() {
    let facts: Facts = serde_json::from_value(json!({
        "ruby_description":"ruby 4.0.7",
        "models": [{"name":"Article", "table":"articles", "columns":[
            {"name":"title", "type":"string", "null":true},
            {"name":"count", "type":"integer", "null":false},
            {"name":"created_at", "type":"datetime", "null":true}],
            "attributes":[{"name":"preview", "type":"boolean"}],
            "attribute_aliases":{"headline":"title"},
            "associations":[{"macro":"has_many", "name":"comments", "class_name":"Comment"},
                {"macro":"belongs_to", "name":"author", "class_name":"User", "options":{"optional":false}},
                {"macro":"belongs_to", "name":"subject", "class_name":"Subject", "options":{"polymorphic":true}}]}],
        "controllers":[{"name":"ArticlesController", "actions":["index"], "callbacks":[
            {"kind":"before", "filter":"load_article", "filter_type":"method"}]}],
        "routes":[{"name":"article", "path":"/articles/:id(.:format)"}]
    })).unwrap();
    let model = TypeModel::from_facts(&facts).unwrap();
    for (query, ty) in [
        ("Article#title", "String?"),
        ("Article#count", "Integer?"),
        (
            "Article#created_at",
            "(Time | ActiveSupport::TimeWithZone)?",
        ),
        ("Article#headline", "String?"),
        ("Article#preview", "bool?"),
        ("Article#author", "User?"),
        ("Article#subject", "untyped"),
        (
            "Article#comments",
            "ActiveRecord::Associations::CollectionProxy[Comment]",
        ),
        ("Article.all", "ActiveRecord::Relation[Article]"),
        ("article_path", "String"),
    ] {
        let sig = model.lookup(query).unwrap();
        assert_eq!(sig.return_type.name, ty, "{query}");
        assert!(!sig.return_type.provenance.is_empty());
    }
    assert_eq!(
        model.lookup("ArticlesController#index").unwrap().roles,
        ["action"]
    );
    assert_eq!(
        model
            .lookup("ArticlesController#load_article")
            .unwrap()
            .roles,
        ["before_action"]
    );
    assert_eq!(
        model.lookup("Article#title=").unwrap().signature(),
        "(untyped) -> untyped"
    );
}

#[test]
fn prism_fixpoint_overrides_and_unsupported_control_flow() {
    let dir = std::env::temp_dir().join(format!("lowrail-types-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let file = dir.join("article.rb");
    let source = "class Article\n  enum :status, [:draft, :live]\n  def banner = label\n  def label = title\n  def answer = 42\n  def risky; return 1 if rand > 0.5; title; end\n  def title = false\n  def self.recent = all\n  scope :published, -> { all }\nend\nmodule Override\n  def title = 3.5\nend\n";
    std::fs::write(&file, source).unwrap();
    let mut methods: Vec<_> = [
        ("banner", 3, false),
        ("label", 4, false),
        ("answer", 5, false),
        ("risky", 6, false),
        ("title", 7, false),
        ("recent", 8, true),
    ]
    .into_iter()
    .map(|(name, line, singleton)| {
        json!({"name":name, "singleton":singleton,
            "source_location":format!("{}:{line}",file.display())})
    })
    .collect();
    methods.push(json!({"name":"published", "singleton":true, "owner":"#<Class:Article>", "source_location":"/rails/named.rb:1", "iseq_kind":"block"}));
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,"ruby_description":"ruby 4.0.7",
        "models":[{"name":"Article", "columns":[{"name":"title", "type":"string"},
            {"name":"status", "type":"integer"}, {"name":"external", "type":"string"}],
            "attribute_aliases":{"state":"status"}}],
        "modules":[{"name":"Article", "ancestors":["Override","Article"], "const_source_location":format!("{}:1",file.display()), "methods":methods},
            {"name":"Override", "methods":[{"name":"title", "source_location":format!("{}:12",file.display())},
                {"name":"external", "owner":"Override", "iseq_kind":"cfunc"}]}]
    })).unwrap();
    let model = TypeModel::from_facts(&facts).unwrap();
    for query in ["Article#title", "Article#label", "Article#banner"] {
        assert_eq!(
            model.lookup(query).unwrap().return_type.name,
            "Float",
            "{query}"
        );
    }
    assert_eq!(
        model.lookup("Article#answer").unwrap().return_type.name,
        "Integer"
    );
    assert_eq!(
        model.lookup("Article#status").unwrap().return_type.name,
        "String?"
    );
    assert_eq!(
        model.lookup("Article#state").unwrap().return_type.name,
        "String?"
    );
    assert_eq!(
        model.lookup("Article#risky").unwrap().return_type.name,
        "untyped"
    );
    assert_eq!(
        model.lookup("Article.recent").unwrap().return_type.name,
        "ActiveRecord::Relation[Article]"
    );
    assert_eq!(
        model.lookup("Article.published").unwrap().return_type.name,
        "ActiveRecord::Relation[Article]"
    );
    assert_eq!(
        model.lookup("Article#external").unwrap().return_type.name,
        "untyped"
    );
    assert!(
        model
            .lookup("Article#banner")
            .unwrap()
            .return_type
            .provenance
            .iter()
            .any(|p| p.detail.contains("Article#label"))
    );
    model.write_rbs(&facts, &dir.join("sig")).unwrap();
    if std::process::Command::new("rbs")
        .arg("--version")
        .output()
        .is_ok()
    {
        let result = std::process::Command::new("rbs")
            .arg("-I")
            .arg(dir.join("sig"))
            .arg("validate")
            .output()
            .unwrap();
        assert!(
            result.status.success(),
            "{}\n{}",
            String::from_utf8_lossy(&result.stdout),
            String::from_utf8_lossy(&result.stderr)
        );
    }
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn rails_catalog_propagates_calls_without_claiming_proof_or_ignoring_overrides() {
    let dir = std::env::temp_dir().join(format!("lowrail-rails-types-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let file = dir.join("article.rb");
    let source = "class Article\n def self.make = new(title: 'hello')\n def self.list = includes(:comments).order(created_at: :desc)\n def self.early = new(title: (external ? (return 7) : 'ok'))\n def self.nested = new(title: helper(external ? (return 7) : 'ok'))\n def self.blocked = new { break 7 }\n def self.custom = Other.new\n def live? = 'override'\nend\nclass Other\n def self.new = 'not an instance'\nend\n";
    let source = format!("{source}class Article\n def self.filtered = where(title: 'hello').exists?\n def self.chain = where\n def self.nil_condition = where(nil).order(:title)\n def self.wrong_chain = where.order(:title)\nend\n");
    std::fs::write(&file, &source).unwrap();
    let parser = crate::parser::Parser::for_runtime("4.0.7").unwrap();
    assert!(parser.parse(source.as_bytes()).errors().next().is_none());
    let mut methods: Vec<_> = [("make",2),("list",3),("early",4),("nested",5),("blocked",6),("custom",7),
        ("filtered",14),("chain",15),("nil_condition",16),("wrong_chain",17)]
        .into_iter().map(|(name,line)| json!({"name":name,"singleton":true,
            "source_location":format!("{}:{line}",file.display())})).collect();
    methods.push(json!({"name":"live?","owner":"Article","source_location":format!("{}:8",file.display())}));
    let mut facts: Facts = serde_json::from_value(json!({"app_root":dir,"ruby_description":"ruby 4.0.7",
        "gems":[{"name":"activerecord","version":"8.1.4","path":"/rails"}],
        "models":[{"name":"Article","primary_key":"id","columns":[{"name":"id","type":"uuid","null":false}]}],
        "modules":[
            {"name":"Article","kind":"class","ancestors":["Article","#<Enum:0x>","Trailing"],"singleton_ancestors":["#<Class:Article>","ActiveRecord::Inheritance::ClassMethods","ActiveRecord::Querying"],"methods":methods},
            {"name":"Other","kind":"class","methods":[{"name":"new","singleton":true,"source_location":format!("{}:11",file.display())}]},
            {"name":"ActiveRecord::Inheritance::ClassMethods","methods":[{"name":"new","owner":"ActiveRecord::Inheritance::ClassMethods","source_location":"/rails/lib/active_record/inheritance.rb:56"}]},
            {"name":"ActiveRecord::Querying","methods":[{"name":"includes","owner":"ActiveRecord::Querying","source_location":"/rails/lib/active_record/querying.rb:24","parameters":[["rest","args"],["keyrest","kwargs"],["block","block"]]},
                {"name":"where","owner":"ActiveRecord::Querying","source_location":"/rails/lib/active_record/querying.rb:24"}]},
            {"name":"ActiveRecord::Relation","kind":"class","ancestors":["ActiveRecord::QueryMethods","ActiveRecord::FinderMethods"]},
            {"name":"ActiveRecord::FinderMethods","methods":[{"name":"exists?","owner":"ActiveRecord::FinderMethods","source_location":"/rails/lib/active_record/relation/finder_methods.rb:357"}]},
            {"name":"ActiveRecord::QueryMethods","methods":[{"name":"order","owner":"ActiveRecord::QueryMethods","source_location":"/rails/lib/active_record/relation/query_methods.rb:1"}]},
            {"name":"Trailing","methods":[{"name":"draft?","owner":"Trailing"}]},
            {"name":"Article._enum_methods_module","synthetic":true,"methods":[
                {"name":"draft?","owner":"#<Enum:0x>","source_location":"/rails/lib/active_record/enum.rb:307"},
                {"name":"in-progress?","owner":"#<Enum:0x>","source_location":"/rails/lib/active_record/enum.rb:307"},
                {"name":"live?","owner":"#<Enum:0x>","source_location":"/rails/lib/active_record/enum.rb:307"}]}
        ]})).unwrap();
    let model = TypeModel::from_facts(&facts).unwrap();
    for (target, expected) in [("Article.new","Article"),("Article.make","Article"),
        ("Article.list","ActiveRecord::Relation[Article]"),("Article.custom","String"),
        ("Article.filtered","bool"),("Article.chain","ActiveRecord::QueryMethods::WhereChain"),
        ("Article.nil_condition","ActiveRecord::Relation[Article]"),
        ("Article#draft?","bool"),("Article#live?","String"),("Article#id","String?")] {
        let ty = model.fact(target,"return").unwrap_or_else(|| panic!("missing {target}"));
        assert_eq!(ty.name, expected, "{target}");
        if !matches!(target, "Article#live?") { assert_eq!(ty.proven_type(), None, "{target}"); }
    }
    for target in ["Article.early","Article.nested","Article.blocked","Article.wrong_chain"] {
        assert_eq!(model.fact(target,"return").unwrap().name, "untyped", "{target}");
    }
    assert!(model.fact("Article.make","return").unwrap().provenance.iter().any(|p| p.source == Source::RailsApi && p.detail.contains("8.1.4")));
    let export = model.export_rbs(&facts);
    assert_eq!(model.fact("Article#in-progress?","return").unwrap().name, "bool");
    assert!(export.files["app.rbs"].contains("def `in-progress?`: () -> bool"));
    model.write_rbs(&facts, &dir.join("sig")).unwrap();
    if std::process::Command::new("rbs").arg("--version").output().is_ok() {
        let check = std::process::Command::new("rbs").arg("-I").arg(dir.join("sig")).arg("validate").output().unwrap();
        assert!(check.status.success(), "{}{}", String::from_utf8_lossy(&check.stdout), String::from_utf8_lossy(&check.stderr));
    }
    // Same owner/name, but the source is replaced or a Rails version is outside
    // the catalog: neither is evidence for the stock constructor contract.
    facts.modules.iter_mut().find(|m| m.name == "ActiveRecord::Inheritance::ClassMethods").unwrap()
        .methods[0].source_location = Some("/custom/inheritance.rb:56".into());
    assert!(TypeModel::from_facts(&facts).unwrap().lookup("Article.new").is_none());
    facts.gems[0].version = "9.0.0".into();
    assert!(TypeModel::from_facts(&facts).unwrap().lookup("Article#draft?").is_none());
    facts.gems[0].version = "8.1.4".into();
    // Erased anonymous owner IDs must not turn a shadowed enum into bool.
    facts.modules[0].ancestors.insert(0, "#<Module:0x>".into());
    facts.modules.push(serde_json::from_value(json!({"name":"Article.ancestors[0]","synthetic":true,
        "methods":[{"name":"draft?","owner":"#<Module:0x>"}]})).unwrap());
    assert_eq!(TypeModel::from_facts(&facts).unwrap().fact("Article#draft?","return").unwrap().name, "untyped");
    facts.modules[0].ancestors.remove(0);
    facts.modules.pop();
    facts.modules[0].ancestors.push("#<Enum:0x>".into());
    assert_eq!(TypeModel::from_facts(&facts).unwrap().fact("Article#draft?","return").unwrap().name, "untyped");
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn view_contracts_keep_nullable_builder_and_unknown_input_boundaries() {
    let dir = std::env::temp_dir().join(format!("lowrail-view-types-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let file = dir.join("helpers.rb");
    std::fs::write(&file, "def builder = tag\ndef maybe_builder = tag(nil)\ndef empty_capture = capture\n").unwrap();
    let groups = [
        ("TagHelper", "tag_helper", vec!["tag", "content_tag", "token_list", "class_names", "cdata_section", "escape_once", "tag_builder"]),
        ("OutputSafetyHelper", "output_safety_helper", vec!["raw", "safe_join", "to_sentence"]),
        ("CaptureHelper", "capture_helper", vec!["capture", "content_for", "provide", "content_for?"]),
    ];
    let mut modules = vec![json!({"name":"Example","kind":"class",
        "ancestors":["Example","ActionView::Helpers::TagHelper","ActionView::Helpers::OutputSafetyHelper","ActionView::Helpers::CaptureHelper"],
        "methods":[
            {"name":"builder","source_location":format!("{}:1",file.display())},
            {"name":"maybe_builder","source_location":format!("{}:2",file.display())},
            {"name":"empty_capture","source_location":format!("{}:3",file.display())}
        ]})];
    for (owner, path, names) in &groups {
        let owner = format!("ActionView::Helpers::{owner}");
        let methods: Vec<_> = names.iter().map(|name| json!({"name":name,"owner":owner,
            "parameters":[["opt","value"]],
            "source_location":format!("/view/lib/action_view/helpers/{path}.rb:1")})).collect();
        modules.push(json!({"name":owner,"methods":methods}));
    }
    let actions: Vec<_> = groups.iter().flat_map(|(_, _, names)| names.iter()).filter(|n| **n != "tag_builder").collect();
    let mut facts: Facts = serde_json::from_value(json!({"app_root":dir,"ruby_description":"ruby 4.0.7",
        "gems":[{"name":"actionview","version":"8.1.4","path":"/view"}],
        "controllers":[{"name":"Example","actions":actions}],"modules":modules})).unwrap();
    let model = TypeModel::from_facts(&facts).unwrap();
    // Existing modeled calls propagate the whole-method contract, not an
    // arity-selected overload; both builder forms must retain its builder arm.
    for (name, expected) in [
        ("tag", "(ActiveSupport::SafeBuffer | ActionView::Helpers::TagHelper::TagBuilder)"),
        ("builder", "(ActiveSupport::SafeBuffer | ActionView::Helpers::TagHelper::TagBuilder)"),
        ("maybe_builder", "(ActiveSupport::SafeBuffer | ActionView::Helpers::TagHelper::TagBuilder)"),
        ("capture", "ActiveSupport::SafeBuffer?"), ("empty_capture", "ActiveSupport::SafeBuffer?"),
        ("content_for", "ActiveSupport::SafeBuffer?"), ("provide", "nil"), ("content_for?", "bool"),
        ("content_tag", "ActiveSupport::SafeBuffer"), ("class_names", "ActiveSupport::SafeBuffer"),
        ("safe_join", "ActiveSupport::SafeBuffer"), ("to_sentence", "ActiveSupport::SafeBuffer"),
    ] {
        let ty = model.fact(&format!("Example#{name}"), "return").unwrap();
        assert_eq!(ty.name, expected, "{name}");
        assert_eq!(ty.proven_type(), None);
        assert!(ty.provenance.iter().any(|p| p.source == Source::RailsApi && p.detail.contains("8.1.4")));
    }
    assert_eq!(model.fact("Example#tag", "arg:value").unwrap().name, "untyped");
    model.write_rbs(&facts, &dir.join("sig")).unwrap();
    if std::process::Command::new("rbs").arg("--version").output().is_ok() {
        let check = std::process::Command::new("rbs").arg("-I").arg(dir.join("sig")).arg("validate").output().unwrap();
        assert!(check.status.success(), "{}{}", String::from_utf8_lossy(&check.stdout), String::from_utf8_lossy(&check.stderr));
    }
    // Included/prepended helpers shadow dependencies without changing the
    // stock defining modules. Do not skip anonymous helpers to stock methods,
    // even when the census holds them under synthetic rather than real names.
    for (ancestor, holder) in [("CustomView", "CustomView"), ("#<Module:0x>", "Example.ancestors[1]")] {
        facts.modules[0].ancestors.insert(1, ancestor.into());
        facts.modules.push(serde_json::from_value(json!({"name":holder,"synthetic":true,
            "methods":[{"name":"tag_builder","owner":ancestor,"source_location":"/custom.rb:1"},
                       {"name":"safe_join","owner":ancestor,"source_location":"/custom.rb:2"}]})).unwrap());
        let changed = TypeModel::from_facts(&facts).unwrap();
        for name in ["tag", "content_tag", "token_list", "class_names", "to_sentence"] {
            assert_eq!(changed.fact(&format!("Example#{name}"), "return").unwrap().name, "untyped", "{ancestor}: {name}");
        }
        facts.modules.pop();
        if ancestor.starts_with('#') {
            assert_eq!(TypeModel::from_facts(&facts).unwrap().fact("Example#tag", "return").unwrap().name, "untyped");
        }
        facts.modules[0].ancestors.remove(1);
    }
    // A replaced helper/callee or unsupported gem cannot supply the contract.
    facts.modules[2].methods.iter_mut().find(|m| m.name == "safe_join").unwrap().source_location = Some("/app/custom.rb:1".into());
    let changed = TypeModel::from_facts(&facts).unwrap();
    for name in ["safe_join", "token_list", "class_names", "to_sentence"] {
        assert_eq!(changed.fact(&format!("Example#{name}"), "return").unwrap().name, "untyped");
    }
    facts.gems[0].version = "9.0.0".into();
    assert_eq!(TypeModel::from_facts(&facts).unwrap().fact("Example#provide", "return").unwrap().name, "untyped");
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn template_source_locations_are_not_parsed_as_ruby() {
    let dir = std::env::temp_dir().join(format!("lowrail-template-types-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let template = dir.join("index.html.erb");
    let raw = dir.join("worker.js");
    let invalid = dir.join("broken.rb");
    std::fs::write(&template, "<h1><%= 42 %></h1>").unwrap();
    std::fs::write(&raw, "self.addEventListener('fetch', () => {});").unwrap();
    std::fs::write(&invalid, "def broken(").unwrap();
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,"ruby_description":"ruby 4.0.7",
        "templates":[{"identifier":template}, {"identifier":raw}],
        "modules":[
            {"name":"Views", "const_source_location":format!("{}:1",template.display()),
             "methods":[{"name":"render_index", "source_location":format!("{}:1",template.display())},
                        {"name":"render_worker", "source_location":format!("{}:1",raw.display())}]},
            {"name":"Broken", "methods":[{"name":"broken", "source_location":format!("{}:1",invalid.display())}]}
        ]
    })).unwrap();
    let model = TypeModel::from_facts(&facts).unwrap();
    assert_eq!(
        model.diagnostics,
        [format!(
            "cannot infer from invalid Ruby: {}",
            invalid.display()
        )]
    );
    assert!(model.lookup("Views#render_index").is_none());
    assert!(model.lookup("Views#render_worker").is_none());
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn sorbet_declarations_recover_shapes_inheritance_and_registry_without_proof() {
    let dir = std::env::temp_dir().join(format!("lowrail-sorbet-types-{}", std::process::id()));
    std::fs::create_dir_all(dir.join("app")).unwrap();
    let file = dir.join("app/contracts.rb");
    let source = r#"module Contract
  Token = T.type_alias { String }
  sig(:final) { params(id: Token, tags: T::Array[T.nilable(Integer)], flags: T::Hash[Symbol, T.any(Integer, T::Array[String])], extra: T.untyped).returns(T.nilable(T.any(String, Integer))) }
  private def fetch(id, tags = [], flags: {}, **extra); external; end
  sig { void }
  def ignored; external; end
  sig { returns(T.proc.void) }
  def opaque; external; end
  sig { type_parameters(:X).returns(T.type_parameter(:X)) }
  def generic; external; end
  sig { returns(Integer).checked(:never) }
  def literal = 42
  sig { returns(Integer) }
  def duplicate = 1
  sig { returns(String) }
  def duplicate = 'two'
end
class Controller
  def literal = 'override'
end
class Shadow
  String = 7
  module Types; end
  sig { returns(String) }
  def scalar; external; end
  sig { returns(Types::Token) }
  def qualified; external; end
end
module Types
  Token = T.type_alias { String }
end
"#;
    std::fs::write(&file, source).unwrap();
    let mut methods: Vec<_> = ["fetch","ignored","opaque","generic","literal","duplicate"].iter().map(|name|
        json!({"name":name,"owner":"Contract","source_location":"/sorbet/lib/types/private/methods/_methods.rb:257",
            "parameters":[["rest","args"],["keyrest","**"],["block","blk"]]})).collect();
    methods.push(json!({"name":"runtime","owner":"Contract","source_location":"/sorbet/lib/types/private/methods/call_validation.rb:120",
        "sorbet_sig":{"version":"0.5.12435","source_location":format!("{}:1",file.display()),"parameters":[["req","value"]],
            "parameter_types":{"value":"Symbol"},"return_type":"Integer"}}));
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,"ruby_description":"ruby 4.0.7","gems":[{"name":"sorbet-runtime","version":"0.5.12435","path":"/sorbet"}],
        "controllers":[{"name":"Controller","actions":["fetch","literal"]}],
        "modules":[{"name":"Contract","kind":"module","const_source_location":format!("{}:1",file.display()),"methods":methods},
            {"name":"Controller","kind":"class","ancestors":["Controller","Contract"],"const_source_location":format!("{}:18",file.display()),
                "methods":[{"name":"literal","owner":"Controller","source_location":format!("{}:19",file.display())}]},
            {"name":"Shadow","kind":"class","const_source_location":format!("{}:21",file.display()),"methods":[
                {"name":"scalar","owner":"Shadow","source_location":"/sorbet/lib/types/private/methods/_methods.rb:257"},
                {"name":"qualified","owner":"Shadow","source_location":"/sorbet/lib/types/private/methods/_methods.rb:257"}]},
            {"name":"Shadow::Types","kind":"module"},
            {"name":"String","kind":"class"},{"name":"Integer","kind":"class"},{"name":"Symbol","kind":"class"}]})).unwrap();
    let mut model = TypeModel::from_facts(&facts).unwrap();
    assert_eq!(model.lookup("Controller#fetch").unwrap().signature(), "(::String, ?Array[::Integer?], ?flags: Hash[::Symbol, (::Integer | Array[::String])], **untyped) -> (::String | ::Integer)?");
    assert_eq!(model.fact("Contract#literal","return").unwrap().evidence, Evidence::Static);
    assert_eq!(model.fact("Controller#literal","return").unwrap().name, "String");
    assert_eq!(model.fact("Contract#runtime","arg:value").unwrap().name, "::Symbol");
    for target in ["Contract#ignored","Contract#opaque","Shadow#scalar","Shadow#qualified"] { assert_eq!(model.fact(target,"return").unwrap().name, "untyped", "{target}"); }
    assert!(model.lookup("Contract#generic").is_none());
    assert!(model.lookup("Contract#duplicate").is_none());
    assert!(model.diagnostics.iter().any(|d| d.contains("ambiguous declarations")));
    let samples = json!({"format":1,"app_root":dir,"types":[
        {"module":"Contract","name":"fetch","calls":3,
            "args":{"id":{"String":3},"tags":{"Array":3},"flags":{"Hash":1,"Array":2}},
            "returns":{"String":2,"NilClass":1}},
        {"module":"Contract","name":"runtime","calls":1,"args":{"value":{"Symbol":1}},"returns":{"Integer":1}}
    ]});
    model.merge_observed(&facts, samples.to_string().as_bytes()).unwrap();
    assert_eq!(model.conflicts.len(), 1, "root names, unions and opaque container elements are not contradictions");
    assert_eq!((model.conflicts[0].slot.as_str(),model.conflicts[0].observed_class.as_str(),model.conflicts[0].count), ("arg:flags","Array",2));
    assert_eq!(model.fact("Contract#fetch","return").unwrap().evidence, Evidence::Static);
    let export = serde_json::to_value(model.export_rbs(&facts)).unwrap();
    let slot = &export["signatures"]["Controller#fetch"]["slots"]["arg:id"];
    assert_eq!(slot["status"], "static");
    assert_eq!(slot["fact"]["provenance"][0]["source"], "sorbet sig");
    assert!(slot["fact"]["provenance"].as_array().unwrap().iter().any(|p| p["detail"].as_str().unwrap().contains("type alias Contract::Token")));
    assert_eq!(export["signatures"]["Contract#opaque"]["slots"]["return"]["status"], "unknown");
    model.write_rbs(&facts, &dir.join("sig")).unwrap();
    if std::process::Command::new("rbs").arg("--version").output().is_ok() {
        let check = std::process::Command::new("rbs").arg("-I").arg(dir.join("sig")).arg("validate").output().unwrap();
        assert!(check.status.success(), "{}{}", String::from_utf8_lossy(&check.stdout), String::from_utf8_lossy(&check.stderr));
    }
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn observed_facts_preserve_static_types_counts_and_proof_boundary() {
    let dir = std::env::temp_dir().join(format!("lowrail-type-observed-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let file = dir.join("article.rb");
    std::fs::write(&file, "class Article\n def literal = 7\n def caller = literal\n def dynamic(value); value.to_s; end\n def self.list = @articles = all\n def exit_literal = @n = 3\n def mutate; @n = 3; literal; @n; end\nend\nmodule ExportHelper\n def undecided(value); external(value); end\nend\n").unwrap();
    let methods: Vec<_> = [("literal",2,false),("caller",3,false),("dynamic",4,false),
        ("list",5,true),("exit_literal",6,false),("mutate",7,false)].into_iter()
        .map(|(name,line,singleton)| json!({"name":name,"singleton":singleton,
            "source_location":format!("{}:{line}",file.display()),
            "parameters":if name == "dynamic" { json!([["req","value"]]) } else { json!([]) }})).collect();
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,"ruby_description":"ruby 4.0.7",
        "models":[{"name":"Article","columns":[{"name":"title","type":"string","null":true}]},
            {"name":"Anonymous.ancestors[0]"}],
        "modules":[{"name":"Article","methods":methods},
            {"name":"ExportHelper","kind":"module","methods":[{"name":"undecided",
                "source_location":format!("{}:10",file.display()),"parameters":[["req","value"]]}]},
            {"name":"Outer","kind":"class"},
            {"name":"Outer::Item","kind":"class"},
            {"name":"Outer::Parameters","kind":"class"}]})).unwrap();
    let mut model = TypeModel::from_facts(&facts).unwrap();
    assert_eq!(model.fact("Article#literal", "return").unwrap().proven_type(), Some("Integer"));
    assert_eq!(model.fact("Article#caller", "return").unwrap().proven_type(), None);
    assert_eq!(model.fact("Article#exit_literal", "ivar:@n").unwrap().proven_type(), Some("Integer"));
    assert!(model.fact("Article#mutate", "ivar:@n").is_none(), "calls can mutate ivars");
    assert_eq!(model.fact("Article.list", "ivar:@articles").unwrap().name, "ActiveRecord::Relation[Article]");
    let samples = json!({"format":1,"app_root":dir,"samples_per_method":16,"types":[
        {"module":"Article","name":"title","calls":5,"returns":{"String":2,"NilClass":1,"Integer":2}},
        {"module":"Article","name":"literal","calls":1,"returns":{"String":1}},
        {"module":"Article","name":"dynamic","calls":3,"saturated":false,
            "args":{"value":{"Symbol":2,"String":1}},"returns":{"String":3},
            "ivars":{"@articles":{"Article::ActiveRecord_Relation":3}}},
        {"module":"#<Class:Article>","singleton":true,"name":"list","calls":2,
            "returns":{"Article::ActiveRecord_Relation":2}},
        {"module":"Outer::Item","name":"read","calls":7,
            "returns":{"Outer::Parameters":1,"Set":1,"Thread::Queue":1,"Tempfile":1,
                "DateTime":1,"Range":1,"NoMethodError":1}}
    ]});
    model.merge_observed(&facts, samples.to_string().as_bytes()).unwrap();
    let title = model.fact("Article#title", "return").unwrap();
    assert_eq!(title.name, "String?", "observations cannot narrow or overwrite a static fact");
    assert_eq!(title.samples, BTreeMap::from([("String".into(),2),("NilClass".into(),1),("Integer".into(),2)]));
    assert_eq!(model.conflicts.len(), 2, "nil is compatible, Integer and literal contradiction are not");
    assert_eq!((model.conflicts[0].method.as_str(),model.conflicts[0].count), ("Article#title",2));
    assert_eq!(model.fact("Article#literal", "return").unwrap().proven_type(), None);
    let value = model.fact("Article#dynamic", "arg:value").unwrap();
    assert_eq!(value.name, "(String | Symbol)");
    assert_eq!(value.evidence, Evidence::Observed);
    assert_eq!(value.proven_type(), None);
    let dynamic = model.lookup("Article#dynamic").unwrap();
    assert_eq!(dynamic.observation.as_ref().unwrap().calls, 3);
    assert!(!dynamic.observation.as_ref().unwrap().saturated);
    assert_eq!(dynamic.return_type.name, "String");
    assert_eq!(dynamic.return_type.evidence, Evidence::Observed);
    assert_eq!(model.fact("Article#dynamic", "ivar:@articles").unwrap().name, "ActiveRecord::Relation[Article]");
    assert!(model.fact("Article#dynamic", "ivar:@articles").unwrap().proven_type().is_none());
    assert_eq!(model.fact("Article#caller", "return").unwrap().name, "Integer", "no inference from observations");
    assert_eq!(model.fact("Outer::Item#read", "return").unwrap().name,
        "(DateTime | NoMethodError[untyped] | Outer::Parameters | Range[untyped] | Set[untyped] | Tempfile | Thread::Queue[untyped])");
    let input = model.typed_facts();
    assert_eq!(input["format"], 1);
    assert_eq!(input["methods"]["Article#dynamic"]["return_type"]["evidence"], "observed");
    let export = serde_json::to_value(model.export_rbs(&facts)).unwrap();
    let signatures = &export["signatures"];
    assert_eq!(signatures["Article#title"]["slots"]["return"]["status"], "static", "schema plus samples is not certified or narrowed");
    assert_eq!(signatures["Article#title"]["rbs"], "() -> String?");
    assert_eq!(signatures["Article#dynamic"]["slots"]["return"]["status"], "observed");
    assert_eq!(signatures["Article#dynamic"]["slots"]["return"]["sample_count"], 3);
    assert_eq!(signatures["Article#dynamic"]["slots"]["arg:value"]["status"], "observed");
    assert_eq!(signatures["Article#exit_literal"]["slots"]["return"]["status"], "proven");
    assert!(signatures["Article#exit_literal"]["slots"]["return"]["scope"].as_str().unwrap().starts_with("body-local"));
    assert_eq!(signatures["Article#mutate"]["slots"]["return"]["status"], "unknown");
    assert_eq!(signatures["Article#mutate"]["rbs"], "() -> untyped");
    assert_eq!(signatures["ExportHelper#undecided"]["rbs"], "(untyped) -> untyped");
    assert_eq!(signatures["ExportHelper#undecided"]["slots"]["arg:value"]["status"], "unknown");
    assert!(signatures["Article#dynamic"].get("status").is_none(), "no whole-signature proof");
    assert!(export["diagnostics"].as_array().unwrap().iter().any(|d| d.as_str().unwrap().contains("RBS cannot declare receiver Anonymous.ancestors[0]")));
    assert!(!export["files"]["app.rbs"].as_str().unwrap().contains("ancestors[0]"), "unrepresentable receivers remain diagnostics, not broken RBS declarations");
    model.write_rbs(&facts, &dir.join("sig")).unwrap();
    if std::process::Command::new("rbs").arg("--version").output().is_ok() {
        let validation = std::process::Command::new("rbs").arg("-I").arg(dir.join("sig")).arg("validate").output().unwrap();
        assert!(validation.status.success(), "{}{}", String::from_utf8_lossy(&validation.stdout), String::from_utf8_lossy(&validation.stderr));
    }
    std::fs::remove_dir_all(dir).unwrap();
}
