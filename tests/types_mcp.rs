//! Optional corpus gate: run `script/corpus real-blog` first.
use serde_json::{Value, json};
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};

#[test]
fn target_ruby_grammar_is_explicit_in_parse_types_and_mcp() {
    let dir = std::env::temp_dir().join(format!("lowrail-target-grammar-{}", std::process::id()));
    std::fs::create_dir_all(dir.join(".lowrail")).unwrap();
    let source = dir.join("example.rb");
    // &nil is accepted by Ruby 4.1, not 4.0. Plain Prism parse() accepts it.
    std::fs::write(&source, "class Example\n def value(&nil); 7; end\nend\n").unwrap();
    let bin = env!("CARGO_BIN_EXE_lowrail");
    let mut facts = json!({"format":1,"app_root":dir,
        "modules":[{"name":"Example","kind":"class","methods":[
            {"name":"value","source_location":format!("{}:2", source.display())}]}]});
    for (runtime, accepted) in [("ruby 4.0.7 (revision fixture)", false), ("ruby 4.1.0preview1 (revision fixture)", true)] {
        let parsed = Command::new(bin).args(["parse", "--ruby-version", runtime]).arg(&source).output().unwrap();
        assert_eq!(parsed.status.success(), accepted, "{runtime}: {:?}", parsed);
        facts["ruby_description"] = json!(runtime);
        std::fs::write(dir.join(".lowrail/facts.json"), facts.to_string()).unwrap();
        let output = Command::new(bin).arg("types").arg(&dir).output().unwrap();
        assert!(output.status.success(), "{:?}", output);
        let types: Value = serde_json::from_slice(&output.stdout).unwrap();
        if accepted {
            assert_eq!(types["methods"]["Example#value"]["return_type"]["name"], "Integer");
            assert_eq!(types["diagnostics"], json!([]));
        } else {
            assert_eq!(types["methods"]["Example#value"], Value::Null);
            assert_eq!(types["diagnostics"], json!([format!("cannot infer from invalid Ruby: {}", source.display())]));
        }
    }
    let missing = Command::new(bin).arg("parse").arg(&source).output().unwrap();
    assert!(!missing.status.success());
    assert!(String::from_utf8_lossy(&missing.stderr).contains("target Ruby required"));
    for runtime in ["", "3.5.0", "4.0", "4.0.future", "4.0.7garbage", "4.2.0", "99.0.0"] {
        let parsed = Command::new(bin).args(["parse", "--ruby-version", runtime]).arg(&source).output().unwrap();
        assert!(!parsed.status.success());
        assert!(String::from_utf8_lossy(&parsed.stderr).contains("unsupported target Ruby"));
        facts["ruby_description"] = json!(runtime);
        std::fs::write(dir.join(".lowrail/facts.json"), facts.to_string()).unwrap();
        let output = Command::new(bin).arg("types").arg(&dir).output().unwrap();
        assert!(!output.status.success());
        assert!(String::from_utf8_lossy(&output.stderr).contains("unsupported target Ruby"));
        let mut server = Command::new(bin).arg("mcp").arg(&dir).stdin(Stdio::piped()).stdout(Stdio::piped()).spawn().unwrap();
        let mut input = server.stdin.take().unwrap();
        writeln!(input, "{}", json!({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}})).unwrap();
        writeln!(input, "{}", json!({"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"type_of","arguments":{"target":"Example#value"}}})).unwrap();
        drop(input);
        let output = server.wait_with_output().unwrap();
        assert!(output.status.success());
        let response: Value = serde_json::from_slice(output.stdout.split(|&b| b == b'\n').nth(1).unwrap()).unwrap();
        assert_eq!(response["result"]["isError"], true);
        assert!(response["result"]["content"][0]["text"].as_str().unwrap().contains("unsupported target Ruby"));
    }
    std::fs::remove_dir_all(dir).unwrap();
}

#[test]
fn real_blog_types_rbs_and_mcp_stdio_round_trip() {
    let root = std::env::var_os("LOWRAIL_TEST_CORPUS_ROOT").map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(".corpus"));
    let app = if root.join("real-blog-r4").is_dir() {
        root.join("real-blog-r4")
    } else { root.join("real-blog") };
    if !app.is_dir() {
        eprintln!("skipping real-blog integration: run script/corpus real-blog");
        return;
    }
    let bin = env!("CARGO_BIN_EXE_lowrail");
    if !app.join(".lowrail/facts.json").exists() {
        assert!(
            Command::new(bin)
                .arg("facts")
                .arg(&app)
                .status()
                .unwrap()
                .success()
        );
    }
    let out = std::env::temp_dir().join(format!("lowrail-real-blog-sig-{}", std::process::id()));
    let result = Command::new(bin)
        .arg("types")
        .arg(&app)
        .arg("--rbs")
        .arg(&out)
        .output()
        .unwrap();
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    let types: Value = serde_json::from_slice(&result.stdout).unwrap();
    assert_eq!(
        types["methods"]["Article#title"]["return_type"]["name"],
        "String?"
    );
    assert_eq!(
        types["methods"]["Article#comments"]["return_type"]["name"],
        "ActiveRecord::Associations::CollectionProxy[Comment]"
    );
    assert_eq!(
        types["methods"]["Lowrail::RouteHelpers#article_path"]["return_type"]["name"],
        "String"
    );
    let app_rbs = std::fs::read_to_string(out.join("app.rbs")).unwrap();
    let support_rbs = std::fs::read_to_string(out.join("lowrail_support.rbs")).unwrap();
    assert_eq!(types["methods"]["Lowrail::RouteHelpers#article_url"]["return_type"]["name"], "String");
    assert!(app_rbs.contains("include ::Lowrail::RouteHelpers"));
    assert!(support_rbs.contains("[self: ::Comment]"));
    assert!(support_rbs.contains("def self.broadcasts_to:"));
    assert!(support_rbs.contains("def self.stale_when_importmap_changes:"));
    let coverage = app_rbs.lines().find_map(|line| line.strip_prefix("# lowrail coverage: ")).unwrap();
    assert_eq!(serde_json::from_str::<Value>(coverage).unwrap(), types["coverage"]);
    let stdout_rbs = Command::new(bin).args(["types", "--rbs"]).arg(&app).output().unwrap();
    assert!(stdout_rbs.status.success());
    assert_eq!(String::from_utf8(stdout_rbs.stdout).unwrap(), format!("{support_rbs}{app_rbs}"));
    if Command::new("rbs").arg("--version").output().is_ok() {
        let validation = Command::new("rbs")
            .arg("-I")
            .arg(&out)
            .arg("validate")
            .output()
            .unwrap();
        assert!(
            validation.status.success(),
            "{}\n{}",
            String::from_utf8_lossy(&validation.stdout),
            String::from_utf8_lossy(&validation.stderr)
        );
    }
    std::fs::remove_dir_all(out).unwrap();
    let mut server = Command::new(bin)
        .arg("mcp")
        .arg(&app)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    let mut input = server.stdin.take().unwrap();
    let mut output = BufReader::new(server.stdout.take().unwrap());
    let mut exchange = |request: Value| -> Value {
        writeln!(input, "{request}").unwrap();
        input.flush().unwrap();
        let mut line = String::new();
        assert!(output.read_line(&mut line).unwrap() > 0);
        serde_json::from_str(&line).unwrap()
    };
    let init = exchange(
        json!({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"corpus-test","version":"1"}}}),
    );
    assert_eq!(init["result"]["serverInfo"]["name"], "lowrail");
    // Drop the closure temporarily to send the notification without reading.
    drop(exchange);
    writeln!(
        input,
        "{}",
        json!({"jsonrpc":"2.0","method":"notifications/initialized"})
    )
    .unwrap();
    for (id, method, params) in [
        (2, "tools/list", json!({})),
        (
            3,
            "tools/call",
            json!({"name":"type_of","arguments":{"target":"Article#title"}}),
        ),
        (4, "tools/call", json!({"name":"export_rbs","arguments":{}})),
    ] {
        writeln!(
            input,
            "{}",
            json!({"jsonrpc":"2.0","id":id,"method":method,"params":params})
        )
        .unwrap();
        input.flush().unwrap();
        let mut line = String::new();
        assert!(output.read_line(&mut line).unwrap() > 0);
        let response: Value = serde_json::from_str(&line).unwrap();
        assert_eq!(response["id"], id);
        if id == 2 {
            assert_eq!(response["result"]["tools"].as_array().unwrap().len(), 14);
        } else if id == 4 {
            assert_eq!(response["result"]["isError"], false);
            let export = &response["result"]["structuredContent"];
            assert_eq!(export["files"]["app.rbs"], app_rbs);
            assert_eq!(export["files"]["lowrail_support.rbs"], support_rbs);
            assert_eq!(export["coverage"], types["coverage"]);
            assert_eq!(export["signatures"]["Article#title"]["slots"]["return"]["status"], "static");
            assert_eq!(serde_json::from_str::<Value>(response["result"]["content"][0]["text"].as_str().unwrap()).unwrap(), *export);
        } else {
            assert_eq!(response["result"]["isError"], false);
            assert_eq!(
                response["result"]["structuredContent"]["signature"],
                "() -> String?"
            );
            assert_eq!(
                response["result"]["structuredContent"]["type"]["return_type"]["provenance"][0]["source"],
                "schema"
            );
        }
    }
    drop(input);
    assert!(server.wait().unwrap().success());
}
