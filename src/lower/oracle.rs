//! Build-time oracle: a booted app (`gem/exe/lowrail-oracle`) that evaluates
//! Ruby in a real view context. Passes use it to partially evaluate helpers
//! with Rails' own code, so Lowrail never re-implements escaping or tag rules.

use std::io::{BufRead, BufReader, Write};
use std::os::fd::AsRawFd;
use std::os::unix::{net::UnixStream, process::CommandExt};
use std::path::Path;
use std::process::{Child, Command, Stdio};

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
    channel: BufReader<UnixStream>,
    next_id: u64,
    pub rails_env: String,
    pub certification_jit: String,
    pub ruby_description: String,
}

impl RubyOracle {
    pub fn start(app: &Path, rails_env: &str, jit: Option<&str>) -> Result<Self, String> {
        let script = crate::facts::gem_dir().join("exe/lowrail-oracle");
        let (parent, child_channel) = UnixStream::pair().map_err(|e| format!("oracle channel: {e}"))?;
        let mut command = Command::new("bundle");
        command.args(["exec", "ruby"]).arg(&script);
        if let Some(jit) = jit { command.arg(jit); }
        // Only the dedicated duplex channel crosses exec at fd 3. Do not
        // borrow stdin/stdout: an app may read or write them during boot/eval.
        // SAFETY: pre_exec performs only async-signal-safe fd operations. The
        // owned socket is captured until spawn, so its source fd remains live.
        unsafe {
            command.pre_exec(move || {
                if libc::dup2(child_channel.as_raw_fd(), 3) == -1 || libc::fcntl(3, libc::F_SETFD, 0) == -1 {
                    return Err(std::io::Error::last_os_error());
                }
                Ok(())
            });
        }
        let child = command
            .current_dir(app)
            .env_remove("RUBYOPT")
            .env("RAILS_ENV", rails_env)
            .env("LOWRAIL", "0")
            .env("LOWRAIL_ORACLE_FD", "3")
            .stdin(Stdio::inherit())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .spawn()
            .map_err(|e| format!("starting oracle: {e}"))?;
        drop(command); // Close the parent's copy of the child end, including on failed boot.
        let mut oracle = Self { child, channel: BufReader::new(parent), next_id: 0,
            rails_env: String::new(), certification_jit: String::new(), ruby_description: String::new() };
        let mut line = String::new();
        oracle.channel.read_line(&mut line).map_err(|e| e.to_string())?;
        let ready: Value = serde_json::from_str(&line).map_err(|e| format!("oracle did not start: {e}: {line}"))?;
        oracle.certification_jit = ready["certification_jit"].as_str().ok_or("oracle missing certification JIT mode")?.to_string();
        oracle.rails_env = ready["rails_env"].as_str().unwrap_or("").to_string();
        oracle.ruby_description = ready["ruby"].as_str().ok_or("oracle missing target Ruby")?.to_string();
        Ok(oracle)
    }
}

impl Oracle for RubyOracle {
    fn eval(&mut self, code: &str) -> Result<Answer, String> {
        self.next_id += 1;
        let req = json!({"id": self.next_id, "code": code});
        writeln!(self.channel.get_mut(), "{req}").map_err(|e| e.to_string())?;
        let mut line = String::new();
        self.channel.read_line(&mut line).map_err(|e| e.to_string())?;
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
