//! Synchronous MCP stdio transport: one JSON-RPC message per line.
#[cfg(test)]
mod tests;
mod tools;

use serde_json::{Value, json};
use std::io::{BufRead, Write};
use std::path::PathBuf;

pub fn cli(args: &[String]) -> Result<(), String> {
    let [app] = args else {
        return Err("usage: lowrail mcp APP".into());
    };
    let app = PathBuf::from(app)
        .canonicalize()
        .map_err(|e| e.to_string())?;
    serve(app, std::io::stdin().lock(), std::io::stdout().lock())
}

pub(super) fn serve(
    app: PathBuf,
    input: impl BufRead,
    mut output: impl Write,
) -> Result<(), String> {
    let mut data = tools::Data::new(app);
    let mut initialized = false;
    for line in input.lines() {
        let line = line.map_err(|e| e.to_string())?;
        if line.trim().is_empty() {
            continue;
        }
        let response = match serde_json::from_str::<Value>(&line) {
            Err(_) => Some(error(Value::Null, -32700, "Parse error")),
            Ok(request) => handle(request, &mut initialized, &mut data),
        };
        if let Some(response) = response {
            serde_json::to_writer(&mut output, &response).map_err(|e| e.to_string())?;
            writeln!(output)
                .and_then(|_| output.flush())
                .map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

fn error(id: Value, code: i32, message: &str) -> Value {
    json!({"jsonrpc":"2.0", "id":id, "error":{"code":code,"message":message}})
}

fn handle(request: Value, initialized: &mut bool, data: &mut tools::Data) -> Option<Value> {
    let id = request.get("id").cloned().unwrap_or(Value::Null);
    if !request.is_object()
        || request["jsonrpc"] != "2.0"
        || !request["method"].is_string()
        || !(id.is_null() || id.is_string() || id.is_number())
    {
        return Some(error(Value::Null, -32600, "Invalid Request"));
    }
    if request.get("id").is_none() {
        return None;
    }
    if let Some(params) = request.get("params")
        && !params.is_object()
    {
        return Some(error(id, -32602, "params must be an object"));
    }
    let result = match request["method"].as_str().unwrap() {
        "initialize" => {
            if *initialized {
                return Some(error(id, -32600, "Already initialized"));
            }
            if !request["params"]["protocolVersion"].is_string() {
                return Some(error(id, -32602, "protocolVersion is required"));
            }
            *initialized = true;
            let version = request["params"]["protocolVersion"].as_str().unwrap();
            let version = match version {
                "2024-11-05" | "2025-03-26" | "2025-06-18" => version,
                _ => "2025-06-18",
            };
            json!({"protocolVersion":version, "capabilities":{"tools":{"listChanged":false}},
                "serverInfo":{"name":"lowrail", "version":env!("CARGO_PKG_VERSION")},
                "instructions":"Read-only boot facts and advisory types. No types authorize lowering without guards."})
        }
        "ping" => json!({}),
        _ if !*initialized => return Some(error(id, -32000, "Initialize first")),
        "tools/list" => json!({"tools":tools::list()}),
        "tools/call" => {
            let Some(name) = request["params"]["name"].as_str() else {
                return Some(error(id, -32602, "tool name is required"));
            };
            if !tools::list().iter().any(|t| t["name"] == name) {
                return Some(error(id, -32602, "Unknown tool"));
            }
            let args = request["params"]
                .get("arguments")
                .cloned()
                .unwrap_or(json!({}));
            match data.call(name, &args) {
                Ok(value) => json!({"content":[{"type":"text", "text":value.to_string()}],
                    "structuredContent":value, "isError":false}),
                Err(message) => {
                    json!({"content":[{"type":"text", "text":message}], "isError":true})
                }
            }
        }
        _ => return Some(error(id, -32601, "Method not found")),
    };
    Some(json!({"jsonrpc":"2.0", "id":id, "result":result}))
}
