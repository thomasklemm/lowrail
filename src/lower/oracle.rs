//! Build-time oracle: a booted app (`gem/exe/lowrail-oracle`) that evaluates
//! Ruby in a real view context. Passes use it to partially evaluate helpers
//! with Rails' own code, so Lowrail never re-implements escaping or tag rules.

use std::io::{BufRead, BufReader, Write};
use std::path::Path;
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};

use serde_json::{Value, json};

#[derive(Debug, Clone, PartialEq)]
pub struct Answer {
    pub value: Value,
    pub class: String,
    pub html_safe: bool,
}

pub trait Oracle {
    /// Evaluates `code` with `self` = a view context. `Err` carries the
    /// Ruby exception as "Class: message".
    fn eval(&mut self, code: &str) -> Result<Answer, String>;

    fn eval_string(&mut self, code: &str) -> Result<(String, bool), String> {
        let a = self.eval(code)?;
        match a.value {
            Value::String(s) => Ok((s, a.html_safe)),
            other => Err(format!("expected a String, got {} {other}", a.class)),
        }
    }
}

pub struct RubyOracle {
    child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
    next_id: u64,
    pub rails_env: String,
}

impl RubyOracle {
    pub fn start(app: &Path, rails_env: &str) -> Result<Self, String> {
        let script = crate::facts::gem_dir().join("exe/lowrail-oracle");
        let mut child = Command::new("bundle")
            .args(["exec", "ruby"])
            .arg(&script)
            .current_dir(app)
            .env("RAILS_ENV", rails_env)
            .env("LOWRAIL", "0")
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .map_err(|e| format!("starting oracle: {e}"))?;
        let stdin = child.stdin.take().unwrap();
        let mut stdout = BufReader::new(child.stdout.take().unwrap());
        let mut line = String::new();
        stdout.read_line(&mut line).map_err(|e| e.to_string())?;
        let ready: Value = serde_json::from_str(&line).map_err(|e| format!("oracle did not start: {e}: {line}"))?;
        Ok(Self { child, stdin, stdout, next_id: 0, rails_env: ready["rails_env"].as_str().unwrap_or("").to_string() })
    }
}

impl Oracle for RubyOracle {
    fn eval(&mut self, code: &str) -> Result<Answer, String> {
        self.next_id += 1;
        let req = json!({"id": self.next_id, "code": code});
        writeln!(self.stdin, "{req}").map_err(|e| e.to_string())?;
        let mut line = String::new();
        self.stdout.read_line(&mut line).map_err(|e| e.to_string())?;
        let resp: Value = serde_json::from_str(&line).map_err(|e| format!("oracle: {e}: {line}"))?;
        if resp["ok"].as_bool() == Some(true) {
            Ok(Answer {
                value: resp["value"].clone(),
                class: resp["class"].as_str().unwrap_or("").to_string(),
                html_safe: resp["html_safe"].as_bool().unwrap_or(false),
            })
        } else {
            Err(resp["error"].as_str().unwrap_or("unknown error").to_string())
        }
    }
}

impl Drop for RubyOracle {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}
