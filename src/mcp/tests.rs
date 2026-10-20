use super::*;

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
    assert_eq!(tools.len(), 10);
    assert!(tools.iter().any(|t| t["name"] == "type_of"));
    assert_eq!(responses[5]["error"]["code"], -32602);
    assert_eq!(responses[6]["result"], json!({}));
}

#[test]
fn data_tools_refresh_facts_and_ledger_without_serving_stale_answers() {
    let dir = std::env::temp_dir().join(format!("lowrail-mcp-{}", std::process::id()));
    std::fs::create_dir_all(dir.join(".lowrail")).unwrap();
    let path = dir.join(".lowrail/facts.json");
    let mut facts = json!({"format":1,
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
        "returns":{"Integer":3},"calls":3}]}).to_string()).unwrap();
    let ty = data.call("type_of", &json!({"target":"Article#title","slot":"return"})).unwrap();
    assert_eq!(ty["fact"]["name"], "bool?");
    assert_eq!(ty["fact"]["samples"]["Integer"], 3);
    assert_eq!(ty["proven_type"], Value::Null);
    assert_eq!(ty["conflicts"][0]["count"], 3);
    std::fs::write(&observed, "{").unwrap();
    assert!(data.call("type_of", &json!({"target":"Article#title"})).is_err());
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
fn method_status_does_not_attribute_neighboring_sites_to_a_method() {
    let dir = std::env::temp_dir().join(format!("lowrail-mcp-span-{}", std::process::id()));
    std::fs::create_dir_all(dir.join(".lowrail")).unwrap();
    let source = dir.join("article.rb");
    std::fs::write(&source, "class Article\n def first\n  article_path(1)\n end\n def second\n  article_path(2)\n end\nend\n").unwrap();
    std::fs::write(dir.join(".lowrail/facts.json"), json!({"format":2,"app_root":"..",
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
