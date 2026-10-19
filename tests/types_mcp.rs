//! Optional corpus gate: run `script/corpus real-blog` first.
use serde_json::{Value, json};
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};

#[test]
fn real_blog_types_rbs_and_mcp_stdio_round_trip() {
    let app = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(".corpus/real-blog");
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
            assert_eq!(response["result"]["tools"].as_array().unwrap().len(), 6);
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
