use super::*;
use serde_json::json;

#[test]
fn coverage_counts_return_and_argument_slots_not_samples_or_ivars() {
    let dir = std::env::temp_dir().join(format!("lowrail-type-coverage-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let file = dir.join("example.rb");
    std::fs::write(&file, "class Example\n def proven = 7\n def inferred = proven\n def sampled(value); external(value); end\n def unknown; external; end\nend\n").unwrap();
    let methods: Vec<_> = [("proven",2),("inferred",3),("sampled",4),("unknown",5)].into_iter()
        .map(|(name,line)| json!({"name":name,"source_location":format!("{}:{line}",file.display()),
            "parameters":if name == "sampled" { json!([["req","value"]]) } else { json!([]) }})).collect();
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,
        "modules":[{"name":"Example","kind":"class","methods":methods}]})).unwrap();
    let mut model = TypeModel::from_facts(&facts);
    model.merge_observed(&facts, json!({"format":1,"app_root":dir,"types":[
        {"module":"Example","name":"sampled","calls":3,"returns":{"String":3},
            "args":{"value":{"Symbol":3}},"ivars":{"@extra":{"Integer":3}}}
    ]}).to_string().as_bytes()).unwrap();
    let expected = json!({"proven":1,"static":1,"observed":2,"unknown":1});
    assert_eq!(model.typed_facts()["coverage"], expected);
    let export = serde_json::to_value(model.export_rbs(&facts)).unwrap();
    assert_eq!(export["coverage"], expected);
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
    let model = TypeModel::from_facts(&facts);
    for (query, ty) in [
        ("Article#title", "String?"),
        ("Article#count", "Integer"),
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
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,
        "models":[{"name":"Article", "columns":[{"name":"title", "type":"string"},
            {"name":"status", "type":"integer"}, {"name":"external", "type":"string"}],
            "attribute_aliases":{"state":"status"}}],
        "modules":[{"name":"Article", "ancestors":["Override","Article"], "const_source_location":format!("{}:1",file.display()), "methods":methods},
            {"name":"Override", "methods":[{"name":"title", "source_location":format!("{}:12",file.display())},
                {"name":"external", "owner":"Override", "iseq_kind":"cfunc"}]}]
    })).unwrap();
    let model = TypeModel::from_facts(&facts);
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
fn template_source_locations_are_not_parsed_as_ruby() {
    let dir = std::env::temp_dir().join(format!("lowrail-template-types-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let template = dir.join("index.html.erb");
    let raw = dir.join("worker.js");
    let invalid = dir.join("broken.rb");
    std::fs::write(&template, "<h1><%= 42 %></h1>").unwrap();
    std::fs::write(&raw, "self.addEventListener('fetch', () => {});").unwrap();
    std::fs::write(&invalid, "def broken(").unwrap();
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,
        "templates":[{"identifier":template}, {"identifier":raw}],
        "modules":[
            {"name":"Views", "const_source_location":format!("{}:1",template.display()),
             "methods":[{"name":"render_index", "source_location":format!("{}:1",template.display())},
                        {"name":"render_worker", "source_location":format!("{}:1",raw.display())}]},
            {"name":"Broken", "methods":[{"name":"broken", "source_location":format!("{}:1",invalid.display())}]}
        ]
    })).unwrap();
    let model = TypeModel::from_facts(&facts);
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
    let facts: Facts = serde_json::from_value(json!({"app_root":dir,
        "models":[{"name":"Article","columns":[{"name":"title","type":"string","null":true}]},
            {"name":"Anonymous.ancestors[0]"}],
        "modules":[{"name":"Article","methods":methods},
            {"name":"ExportHelper","kind":"module","methods":[{"name":"undecided",
                "source_location":format!("{}:10",file.display()),"parameters":[["req","value"]]}]},
            {"name":"Outer","kind":"class"},
            {"name":"Outer::Item","kind":"class"},
            {"name":"Outer::Parameters","kind":"class"}]})).unwrap();
    let mut model = TypeModel::from_facts(&facts);
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
        {"module":"Outer::Item","name":"read","calls":4,
            "returns":{"Outer::Parameters":1,"Set":1,"Thread::Queue":1,"Tempfile":1}}
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
        "(Outer::Parameters | Set[untyped] | Tempfile | Thread::Queue[untyped])");
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
