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
    assert_eq!(tools.len(), 6);
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
    let ledger = json!([{"method":"Article#title","reason":"unsupported"}]);
    std::fs::write(dir.join(".lowrail/ledger.json"), ledger.to_string()).unwrap();
    assert_eq!(
        data.call("lowering_ledger", &json!({})).unwrap()["ledger"],
        ledger
    );
    assert_eq!(
        data.call("diagnostics", &json!({})).unwrap()["status"],
        "placeholder"
    );
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
    std::fs::remove_dir_all(dir).unwrap();
}
