use super::*;
use serde_json::json;

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
            {"name":"status", "type":"integer"}, {"name":"external", "type":"string"}]}],
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
