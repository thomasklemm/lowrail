use super::*;

#[test]
fn callers_and_view_inputs_are_bounded_contextual_and_refresh_sources() {
    let dir = std::env::temp_dir().join(format!("lowrail-mcp-useful-{}", std::process::id()));
    std::fs::create_dir_all(dir.join(".lowrail")).unwrap();
    std::fs::create_dir_all(dir.join("app/controllers")).unwrap();
    let source = dir.join("app/controllers/rooms_controller.rb");
    let ruby = "class RoomsController\n def index; @value = 7; end\n def value = 7\n def caller = value\n def dynamic(obj) = obj.value\n def make = User.new\n def other = Other.new\nend\n";
    std::fs::write(&source, ruby).unwrap();
    std::fs::create_dir_all(dir.join("app/views/rooms")).unwrap();
    for name in ["index", "_card"] {
        std::fs::write(dir.join(format!("app/views/rooms/{name}.html.erb")), "template").unwrap();
    }
    use sha2::{Digest, Sha256};
    let digest = format!("{:x}", Sha256::digest(b"template"));
    let methods: Vec<_> = [("index",2), ("value",3), ("caller",4), ("dynamic",5), ("make",6), ("other",7)].into_iter()
        .map(|(name,line)| json!({"name":name,"owner":"RoomsController","source_location":format!("{}:{line}",source.display())})).collect();
    let facts = json!({"format":1,"app_root":dir,"ruby_description":"ruby 4.0.7",
        "modules":[{"name":"RoomsController","const_source_location":format!("{}:1",source.display()),"methods":methods},
            {"name":"User","singleton_ancestors":["Class"]}, {"name":"Other","singleton_ancestors":["Class"]},
            {"name":"Class","methods":[{"name":"new","owner":"Class","iseq_kind":"cfunc"}]},
            {"name":"Array","methods":[{"name":"join","owner":"Array","iseq_kind":"cfunc"}]}],
        "controllers":[{"name":"RoomsController","actions":["index"]}],
        "routes":[{"controller":"rooms","action":"index"}],
        "templates":[{"identifier":format!("{}/app/views/rooms/index.html.erb",dir.display()),"virtual_path":"rooms/index",
            "source_sha256":digest,"code":"render 'card', value: @value, sampled: @sampled, joined: @sampled.join; render partial: 'card', collection: @sampled, as: :entry"},
            {"identifier":format!("{}/app/views/rooms/_card.html.erb",dir.display()),"virtual_path":"rooms/_card","source_sha256":digest,"strict_locals":"value:, sampled:"}]});
    std::fs::write(dir.join(".lowrail/facts.json"), facts.to_string()).unwrap();
    std::fs::write(dir.join(".lowrail/observed.json"), json!({"format":1,"app_root":dir,"types":[
        {"module":"RoomsController","name":"index","ivars":{"@sampled":{"Array":1}},
            "collection_members":{"ivar:@sampled":{"Array.element":{"String":1}}}}]}).to_string()).unwrap();
    let mut data = tools::Data::new(dir.clone());
    let callers = data.call("callers", &json!({"target":"RoomsController#value"})).unwrap();
    assert_eq!(callers["callers"].as_array().unwrap().len(), 1);
    assert_eq!(callers["callers"][0]["caller"], "RoomsController#caller");
    assert_eq!(callers["callers"][0]["line"], 4);
    assert_eq!(callers["unresolved"][0]["line"], 5);
    assert_eq!(callers["complete"], false);
    let constructors = data.call("callers", &json!({"target":"User.new"})).unwrap();
    assert_eq!(constructors["callers"].as_array().unwrap().len(), 1, "shared Class#new must not conflate concrete receivers");
    assert_eq!(constructors["callers"][0]["caller"], "RoomsController#make");
    let view = data.call("view_locals", &json!({"path":"rooms/_card"})).unwrap();
    let incoming = &view["templates"][0]["incoming"][0];
    assert_eq!(incoming["action"], "RoomsController#index");
    assert_eq!(incoming["locals"]["value"]["name"], "Integer");
    assert_eq!(incoming["locals"]["value"]["evidence"], "static");
    assert_eq!(incoming["locals"]["sampled"]["name"], "Array[String]");
    assert_eq!(incoming["locals"]["sampled"]["evidence"], "observed");
    assert_eq!(incoming["locals"]["joined"]["name"], "String");
    assert_eq!(incoming["locals"]["joined"]["evidence"], "observed", "receiver evidence must survive a call");
    let collection = &view["templates"][0]["incoming"][1];
    assert_eq!(collection["local_names"], json!(["entry", "entry_counter", "entry_iteration"]));
    assert_eq!(collection["locals"]["entry"]["name"], "String");
    assert_eq!(collection["locals"]["entry"]["evidence"], "observed");
    assert_eq!(view["templates"][0]["strict_locals"], "value:, sampled:");
    assert_eq!(view["complete"], false);
    std::fs::write(&source, ruby.replace("def caller = value", "def caller = other")).unwrap();
    assert_eq!(data.call("callers", &json!({"target":"RoomsController#value"})).unwrap()["callers"], json!([]));
    assert_eq!(data.call("view_locals", &json!({"path":"unknown"})).unwrap()["available"], false);
    std::fs::write(dir.join("app/views/rooms/_card.html.erb"), "changed").unwrap();
    assert_eq!(data.call("view_locals", &json!({"path":"rooms/_card"})).unwrap()["available"], false);
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn protocol_errors_notifications_and_tool_discovery() {
    let input = b"not json\n[]\n\
        {\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}\n\
        {\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\"}}\n\
        {\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}\n\
        {\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/list\"}\n\
        {\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"unknown\"}}\n\
        {\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"ping\"}\n";
    let mut output = Vec::new();
    serve(PathBuf::from("."), input.as_slice(), &mut output).unwrap();
    let responses: Vec<Value> = String::from_utf8(output)
        .unwrap()
        .lines()
        .map(|s| serde_json::from_str(s).unwrap())
        .collect();
    assert_eq!(responses.len(), 7, "notifications must not get replies");
    assert_eq!(responses[0]["error"]["code"], -32700);
    assert_eq!(responses[1]["error"]["code"], -32600);
    assert_eq!(responses[2]["error"]["code"], -32000);
    assert_eq!(responses[3]["result"]["protocolVersion"], "2025-06-18");
    let tools = responses[4]["result"]["tools"].as_array().unwrap();
    assert_eq!(tools.len(), 17);
    assert!(tools.iter().any(|t| t["name"] == "type_of"));
    assert_eq!(responses[5]["error"]["code"], -32602);
    assert_eq!(responses[6]["result"], json!({}));
}

#[test]
fn data_tools_refresh_facts_and_ledger_without_serving_stale_answers() {
    let dir = std::env::temp_dir().join(format!("lowrail-mcp-{}", std::process::id()));
    std::fs::create_dir_all(dir.join(".lowrail")).unwrap();
    let path = dir.join(".lowrail/facts.json");
    let mut facts = json!({"format":1,"ruby_description":"ruby 4.0.7",
        "models":[{"name":"Article","columns":[{"name":"title","type":"string","null":true}],
            "validations":[{"kind":"presence","attributes":["title"]}]}],
        "modules":[{"name":"Article","ancestors":["Override","Article"],"methods":[{"name":"secret","owner":"Article"}]},
            {"name":"Override","methods":[{"name":"secret","owner":"Override","iseq_kind":"cfunc"}]}],
        "routes":[{"name":"article","path":"/articles/:id","controller":"articles"},
            {"name":"article_feed","path":"/feed","controller":"feeds"}]});
    std::fs::write(&path, facts.to_string()).unwrap();
    let mut data = tools::Data::new(dir.clone());
    let method = data
        .call("method_facts", &json!({"target":"Article#secret"}))
        .unwrap();
    assert_eq!(method["method"]["owner"], "Override");
    assert_eq!(method["origin"]["iseq_kind"], "cfunc");
    let model = data.call("model", &json!({"name":"Article"})).unwrap();
    assert_eq!(model["validations_available"], true);
    assert_eq!(model["model"]["validations"][0]["kind"], "presence");
    let routes = data
        .call(
            "routes",
            &json!({"name":"article","controller":"articles","path":"/:id"}),
        )
        .unwrap();
    assert_eq!(routes["routes"].as_array().unwrap().len(), 1);
    assert_eq!(routes["routes"][0]["path"], "/articles/:id");
    assert_eq!(
        data.call("lowering_ledger", &json!({})).unwrap()["available"],
        false
    );
    assert_eq!(data.call("seal_ledger", &json!({})).unwrap()["available"], false);
    let seal = json!({"format":1,"ledger":[{"pattern":"config_changed","file":"test/example.rb","line":12,"remedy":"move to boot"}]});
    std::fs::write(dir.join(".lowrail/seal.json"), seal.to_string()).unwrap();
    assert_eq!(data.call("seal_ledger", &json!({})).unwrap()["report"], seal);
    assert_eq!(data.call("doctor", &json!({})).unwrap()["available"], false);
    let doctor = json!({"format":1,"boot_ok":true,"baseline_ok":true,"static":{"hints":[]}});
    std::fs::write(dir.join(".lowrail/doctor.json"), doctor.to_string()).unwrap();
    assert_eq!(data.call("doctor", &json!({})).unwrap()["report"], doctor);
    let ledger = json!([{"method":"Article#title","reason":"unsupported"}]);
    std::fs::write(dir.join(".lowrail/ledger.json"), ledger.to_string()).unwrap();
    assert_eq!(
        data.call("lowering_ledger", &json!({})).unwrap()["ledger"],
        ledger
    );
    assert_eq!(data.call("diagnostics", &json!({})).unwrap()["conflicts"], json!([]));
    assert!(data.call("type_of", &json!({})).is_err());
    assert!(data.call("routes", &json!({"path":42})).is_err());
    assert!(data.call("model", &json!({"name":"Missing"})).is_err());
    facts["models"][0]["columns"][0]["type"] = json!("integer");
    std::fs::write(&path, facts.to_string()).unwrap();
    assert_eq!(
        data.call("type_of", &json!({"target":"Article#title"}))
            .unwrap()["type"]["return_type"]["name"],
        "Integer?"
    );
    std::fs::write(&path, "{").unwrap();
    assert!(
        data.call("type_of", &json!({"target":"Article#title"}))
            .is_err()
    );
    facts["models"][0]["columns"][0]["type"] = json!("boolean");
    std::fs::write(&path, facts.to_string()).unwrap();
    assert_eq!(
        data.call("type_of", &json!({"target":"Article#title"}))
            .unwrap()["type"]["return_type"]["name"],
        "bool?"
    );
    let observed = dir.join(".lowrail/observed.json");
    std::fs::write(&observed, json!({"format":1,"types":[{"module":"Article","name":"title",
        "returns":{"Integer":3},"calls":3}, {"module":"Article","name":"seen","returns":{"String":2},"calls":2}]}).to_string()).unwrap();
    let ty = data.call("type_of", &json!({"target":"Article#title","slot":"return"})).unwrap();
    assert_eq!(ty["fact"]["name"], "bool?");
    assert_eq!(ty["fact"]["samples"]["Integer"], 3);
    assert_eq!(ty["proven_type"], Value::Null);
    assert_eq!(ty["conflicts"][0]["count"], 3);
    let export = data.call("export_rbs", &json!({})).unwrap();
    assert_eq!(export["signatures"]["Article#title"]["slots"]["return"]["status"], "static");
    assert_eq!(export["signatures"]["Article#seen"]["rbs"], "(*untyped) -> String");
    assert_eq!(export["signatures"]["Article#seen"]["slots"]["return"]["status"], "observed");
    assert_eq!(export["signatures"]["Article#seen"]["slots"]["return"]["sample_count"], 2);
    assert_eq!(export["signatures"]["Article#title="]["slots"]["return"]["status"], "unknown");
    assert_eq!(export["signatures"]["Article#title="]["rbs"], "(untyped) -> untyped");
    assert!(!dir.join("sig").exists(), "MCP export is read-only");
    std::fs::write(&observed, "{").unwrap();
    assert!(data.call("type_of", &json!({"target":"Article#title"})).is_err());
    assert!(data.call("export_rbs", &json!({})).is_err(), "corrupt samples cannot serve a stale export");
    std::fs::remove_file(&observed).unwrap();
    assert_eq!(data.call("diagnostics", &json!({})).unwrap()["conflicts"], json!([]));
    assert_eq!(data.call("lowering_status", &json!({"target":"Article#title"})).unwrap()["sites"], ledger);
    assert_eq!(data.call("verify_stats", &json!({})).unwrap()["available"], false);
    let manifest = json!({"units":[{"id":3,"pass":"route/path"}]});
    std::fs::create_dir_all(dir.join(".lowrail/verify")).unwrap();
    std::fs::write(dir.join(".lowrail/manifest.json"), manifest.to_string()).unwrap();
    std::fs::write(dir.join(".lowrail/verify/last.json"), json!({"format":1,"manifest":manifest,
        "passes":{"route/path":{"hits":7,"fallbacks":2}},
        "report":{"on":{"unit_hits":{"3":7},"unit_fallbacks":{"3":2}}}}).to_string()).unwrap();
    let stats = data.call("verify_stats", &json!({})).unwrap();
    assert_eq!(stats["matches_current_manifest"], true);
    assert_eq!(stats["passes"]["route/path"]["fallbacks"], 2);
    std::fs::write(dir.join(".lowrail/manifest.json"), "{}").unwrap();
    assert_eq!(data.call("verify_stats", &json!({})).unwrap()["matches_current_manifest"], false);
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn source_queries_resolve_known_calls_refuse_dynamic_self_and_refresh_changed_source() {
    let dir = std::env::temp_dir().join(format!("lowrail-mcp-position-{}", std::process::id()));
    std::fs::create_dir_all(dir.join(".lowrail")).unwrap();
    let file = dir.join("example.rb");
    let source = "class Example\n def value = 7\n def caller = value\n def dynamic(arg) = arg.value\n def shifted = object.instance_exec { value }\nend\n";
    std::fs::write(&file, source).unwrap();
    let methods: Vec<_> = [("value",2),("caller",3),("dynamic",4),("shifted",5)].iter().map(|(name,line)|
        json!({"name":name,"owner":"Example","source_location":format!("{}:{line}",file.display())})).collect();
    std::fs::write(dir.join(".lowrail/facts.json"), json!({"format":1,"app_root":dir,"ruby_description":"ruby 4.0.7",
        "modules":[{"name":"Example","kind":"class","methods":methods}]}).to_string()).unwrap();
    let mut data = tools::Data::new(dir.clone());
    let position = json!({"path":"example.rb","line":3,"column":15});
    let ty = data.call("type_at_position", &position).unwrap();
    assert_eq!(ty["target"], "Example#value");
    assert_eq!(ty["fact"]["name"], "Integer");
    assert_eq!(ty["fact"]["evidence"], "static");
    assert_eq!(ty["proven_type"], Value::Null);
    let definition = data.call("find_definition", &json!({"target":"Example#caller"})).unwrap();
    assert_eq!(definition["path"], file.to_str().unwrap());
    assert_eq!(definition["line"], 3);
    assert_eq!(definition["origin"]["category"], "def");
    for (line, column) in [(4,25),(5,39)] {
        assert_eq!(data.call("type_at_position", &json!({"path":"example.rb","line":line,"column":column})).unwrap()["available"], false);
    }
    for (line, column) in [(0,1),(99,1),(2,99)] {
        assert!(data.call("type_at_position", &json!({"path":"example.rb","line":line,"column":column})).is_err());
    }
    assert!(data.call("type_at_position", &json!({"path":"/etc/passwd","line":1,"column":1})).is_err());
    std::fs::write(&file, source.replace("= 7", "= 'changed'")).unwrap();
    assert_eq!(data.call("type_of", &json!({"target":"Example#caller"})).unwrap()["signature"], "() -> String");
    assert_eq!(data.call("type_at_position", &position).unwrap()["fact"]["name"], "String");
    std::fs::write(&file, "def invalid(").unwrap();
    assert!(data.call("type_at_position", &position).is_err());
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn method_status_does_not_attribute_neighboring_sites_to_a_method() {
    let dir = std::env::temp_dir().join(format!("lowrail-mcp-span-{}", std::process::id()));
    std::fs::create_dir_all(dir.join(".lowrail")).unwrap();
    let source = dir.join("article.rb");
    std::fs::write(&source, "class Article\n def first\n  article_path(1)\n end\n def second\n  article_path(2)\n end\nend\n").unwrap();
    std::fs::write(dir.join(".lowrail/facts.json"), json!({"format":2,"app_root":"..","ruby_description":"ruby 4.0.7",
        "app_paths":{"values":["/modules/0/methods/0/source_location","/modules/0/methods/1/source_location"],"keys":[]},
        "modules":[{"name":"Article","methods":[
        {"name":"first","source_location":"article.rb:2"},
        {"name":"second","source_location":"article.rb:5"}]}]}).to_string()).unwrap();
    std::fs::write(dir.join(".lowrail/ledger.json"), json!([
        {"target":source,"line":3,"outcome":"lowered","pass":"route/path"},
        {"target":source,"line":6,"outcome":"refused","reason":"argument_shape","pass":"route/path"}
    ]).to_string()).unwrap();
    let mut data = tools::Data::new(dir.clone());
    let first = data.call("lowering_status", &json!({"target":"Article#first"})).unwrap();
    assert_eq!(first["status"], "lowered");
    assert_eq!(first["sites"].as_array().unwrap().len(), 1);
    let second = data.call("lowering_status", &json!({"target":"Article#second"})).unwrap();
    assert_eq!(second["status"], "refused");
    assert_eq!(second["sites"][0]["reason"], "argument_shape");
    assert_eq!(data.call("lowering_status", &json!({"target":"Article#missing"})).unwrap()["status"], "not_recorded");
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn explanation_round_trip_preserves_certificates_refusals_and_counter_provenance() {
    let dir = std::env::temp_dir().join(format!("lowrail-explain-{}", std::process::id()));
    let artifact = dir.join(".lowrail");
    std::fs::create_dir_all(artifact.join("verify")).unwrap();
    std::fs::write(artifact.join("facts.json"), json!({"format":2,"app_root":"..","yjit":false,
        "rails_version":"8.1.4","app_paths":{"values":[],"keys":[]}}).to_string()).unwrap();
    let mut manifest = json!({"format":2,"app_root":"..","app_paths":{"keys":[],"values":["/units/0/data/site/source_location/0"]},
        "certification_jit":"yjit","rails_env":"production","tier":"sealed-v1","selected_passes":["sealed/form_scaffold"],
        "units":[{"id":18,"pass":"sealed/form_scaffold","kind":"method","target":"ArticlesController#form_with","facts":[],
          "data":{"inventory":{"audited":"retained"},"site":{"source_location":["app/views/articles/show.html.erb",23],"handler_sha256":"exact"}}}]});
    std::fs::write(artifact.join("manifest.json"), manifest.to_string()).unwrap();
    let mut ledger = json!([
        {"pass":"sealed/form_scaffold","target":"app/views/articles/show.html.erb","line":23,"site":"form_with","outcome":"lowered","reason":"lowered","detail":"lowered","copies":1},
        {"pass":"sealed/form_scaffold","target":"app/views/articles/show.html.erb","line":24,"site":"form_with","outcome":"refused","reason":"dynamic_options","detail":"original retained"},
        {"pass":"jit/shape","target":"app/views/articles/show.html.erb","line":23,"outcome":"warning","reason":"uninspected","detail":"not a refusal"}
    ]);
    std::fs::write(artifact.join("ledger.json"), ledger.to_string()).unwrap();
    std::fs::write(artifact.join("verify/last.json"), json!({"format":1,"manifest":manifest,
        "report":{"on":{"unit_hits":{"18":17},"unit_fallbacks":{"18":3},"jit_modes":[{
            "certification":"yjit","admission":"yjit","current":"yjit","refusal":null}]}}}).to_string()).unwrap();
    let requests = [json!({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}),
        json!({"jsonrpc":"2.0","id":2,"method":"tools/list"}),
        json!({"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"explain_unit","arguments":{"id":18}}}),
        json!({"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"explain_site","arguments":{"location":"app/views/articles/show.html.erb:24"}}})];
    let input = requests.iter().map(|r| format!("{r}\n")).collect::<String>();
    let mut output = Vec::new();
    serve(dir.clone(), input.as_bytes(), &mut output).unwrap();
    let responses = String::from_utf8(output).unwrap().lines().map(|s| serde_json::from_str::<Value>(s).unwrap()).collect::<Vec<_>>();
    let tool = responses[1]["result"]["tools"].as_array().unwrap().iter().find(|t| t["name"] == "explain_unit").unwrap();
    assert_eq!(tool["inputSchema"]["properties"]["id"]["type"], "integer");
    assert_eq!(tool["outputSchema"]["properties"]["units"]["items"]["$ref"], "#/$defs/unit");
    let value = &responses[2]["result"]["structuredContent"];
    let typed: crate::explain::Report = serde_json::from_value(value.clone()).unwrap();
    assert_eq!(serde_json::to_value(&typed).unwrap(), *value, "typed MCP schema round trip");
    assert_eq!(serde_json::from_str::<Value>(responses[2]["result"]["content"][0]["text"].as_str().unwrap()).unwrap(), *value);
    assert_eq!(value["selected_passes"], json!(["sealed/form_scaffold"]));
    assert_eq!(value["certification_jit"], "yjit");
    assert_eq!(value["facts"]["yjit"], false, "facts mode is not build certification");
    assert_eq!(value["units"][0]["counts"], json!({"hits":17,"fallbacks":3}));
    assert_eq!(value["units"][0]["certificates"]["data"]["inventory"]["audited"], "retained");
    assert_eq!(value["units"][0]["activation_refusal"]["code"], "effectful_form_certification");
    assert!(value["units"][0]["activation_refusal"]["detail"].as_str().unwrap().contains("old effectful form certificate"));
    assert!(typed.render().contains("current runtime policy refuses [effectful_form_certification]"));
    assert!(typed.render().contains("Hook dependency: none for this unit"));
    assert_eq!(value["sites"].as_array().unwrap().len(), 1, "neighboring refusal/warning must not inherit counters");
    assert_eq!(value["sites"][0]["status"], "lowered");
    assert!(typed.render().contains("FormScaffold.valid?"));
    assert!(typed.render().contains("seal epoch zero"));
    assert_eq!(responses[3]["result"]["structuredContent"]["sites"][0]["status"], "refused");
    assert_eq!(responses[3]["result"]["structuredContent"]["units"], json!([]));
    let mut data = tools::Data::new(dir.clone());
    assert!(data.call("explain_unit", &json!({"id":"18"})).is_err());
    assert!(data.call("explain_site", &json!({"location":"x:0"})).is_err());
    let unknown = data.call("explain_site", &json!({"location":"app/views/articles/show.html.erb:25"})).unwrap();
    assert_eq!(unknown["sites"][0]["status"], "left_original");
    assert_eq!(unknown["sites"][0]["reason"]["code"], "not_recorded");
    let mut guarded = manifest.clone();
    guarded["units"][0]["facts"] = json!([{"receiver":"Article","method":"title"}]);
    guarded["files"] = json!({"app/models/article.rb": {}});
    std::fs::write(artifact.join("manifest.json"), guarded.to_string()).unwrap();
    let hooks = crate::explain::read(&dir, None, None, None, None, None).unwrap().render();
    assert!(hooks.contains("requires ModuleHooks and ObjectHooks"));
    assert!(hooks.contains("Source delivery requires ModuleHooks"));
    manifest["certification_jit"] = json!("interpreter");
    std::fs::write(artifact.join("manifest.json"), manifest.to_string()).unwrap();
    let stale = data.call("explain_unit", &json!({"id":18})).unwrap();
    assert_eq!(stale["stats"]["binding"], "stale_manifest");
    assert_eq!(stale["units"][0]["counts"], Value::Null);
    std::fs::write(artifact.join("verify/last.json"), json!({"format":1,"manifest":manifest,
        "report":{"on":{"unit_hits":{},"unit_fallbacks":{},"jit_modes":[{"certification":"interpreter","admission":"yjit","current":"yjit",
            "refusal":"certification JIT mode mismatch: built interpreter, running yjit; rebuild with --jit yjit"}]}}}).to_string()).unwrap();
    let mismatch = data.call("explain_unit", &json!({"id":18})).unwrap();
    assert_eq!(mismatch["stats"]["refusals"][0]["code"], "jit_mode_mismatch");
    assert_eq!(mismatch["units"][0]["counts"], json!({"hits":0,"fallbacks":0}));
    assert!(serde_json::from_value::<crate::explain::Report>(mismatch).unwrap().render().contains("runtime refused [jit_mode_mismatch]"));
    std::fs::remove_file(artifact.join("verify/last.json")).unwrap();
    let missing = data.call("explain_unit", &json!({"id":18})).unwrap();
    assert_eq!(missing["stats"], Value::Null);
    assert_eq!(missing["units"][0]["counts"], Value::Null, "missing stats are not zero coverage");
    std::fs::write(artifact.join("stats.json.123"), json!({"unit_hits":{"18":29},"unit_fallbacks":{"18":2},
        "unit_refusals":{"18":["passive activation unavailable"]}}).to_string()).unwrap();
    let unbound = data.call("explain_unit", &json!({"id":18,"stats":".lowrail/stats.json.123"})).unwrap();
    assert_eq!(unbound["stats"]["binding"], "unbound_snapshot");
    assert_eq!(unbound["stats"]["unit_hits"]["18"], 29);
    assert_eq!(unbound["stats"]["unit_refusals"]["18"], json!(["passive activation unavailable"]));
    assert_eq!(unbound["units"][0]["counts"], Value::Null, "unbound raw counts stay visible, not attributed to this artifact");
    manifest["units"][0]["data"]["passive"] = json!({"version":1});
    std::fs::write(artifact.join("manifest.json"), manifest.to_string()).unwrap();
    let passive = data.call("explain_unit", &json!({"id":18,"stats":".lowrail/stats.json.123"})).unwrap();
    assert_eq!(passive["units"][0]["activation_refusal"], Value::Null, "eligibility is not a live activation claim");
    assert_eq!(passive["stats"]["unit_refusals"]["18"], json!(["passive activation unavailable"]), "keep observed terminal refusals visible");
    // A compiler-dropped unit leaves its successful ledger row intact, but
    // cannot be reported as delivered or assigned old unit counters.
    manifest["units"] = json!([]);
    manifest["app_paths"]["values"] = json!([]);
    std::fs::write(artifact.join("manifest.json"), manifest.to_string()).unwrap();
    let dropped = data.call("explain_site", &json!({"location":"app/views/articles/show.html.erb:23"})).unwrap();
    assert_eq!(dropped["sites"][0]["reason"]["code"], "not_emitted");
    assert_eq!(dropped["sites"][1]["status"], "ledgered");
    ledger = json!([{"pass":"active_record/instantiate","target":"Contact","line":0,"site":"Contact._load_from_sql",
        "outcome":"refused","reason":"rails_implementation","detail":"unaudited Rails implementation","copies":1},
        {"pass":"active_record/instantiate","target":"Other","line":0,"site":"Other._load_from_sql",
        "outcome":"refused","reason":"different_reason","detail":"neighboring class"}]);
    std::fs::write(artifact.join("ledger.json"), ledger.to_string()).unwrap();
    std::fs::write(artifact.join("facts.json"), json!({"format":2,"app_root":"..","rails_version":"8.0.5",
        "app_paths":{"values":["/modules/0/const_source_location","/modules/1/const_source_location"],"keys":[]},
        "modules":[{"name":"Contact","const_source_location":"app/models/entities/contact.rb:40"},
            {"name":"Other","const_source_location":"app/models/entities/contact.rb:41"}]}).to_string()).unwrap();
    let crm = crate::explain::read(&dir, None, None, None, None, Some("active_record/instantiate")).unwrap();
    assert_eq!(crm.sites[0].status, crate::explain::Status::Refused);
    assert_eq!(crm.sites[0].reason.code, "rails_implementation");
    assert_eq!(crm.sites[0].reason.detail, "unaudited Rails implementation");
    assert_eq!(crm.facts.as_ref().unwrap().rails_version.as_deref(), Some("8.0.5"));
    let crm_site = data.call("explain_site", &json!({"location":"app/models/entities/contact.rb:40"})).unwrap();
    assert_eq!(crm_site["sites"].as_array().unwrap().len(), 1);
    assert_eq!(crm_site["sites"][0]["target"], "Contact");
    assert_eq!(crm_site["sites"][0]["location"]["origin"], "boot_constant");
    assert_eq!(crm_site["sites"][0]["reason"]["code"], "rails_implementation");
    assert_eq!(crm_site["units"], json!([]));
    std::fs::write(artifact.join("ledger.json"), "{").unwrap();
    assert!(data.call("explain_site", &json!({"location":"x:1"})).is_err(), "no stale successful answer");
    std::fs::remove_dir_all(dir).unwrap();
}
