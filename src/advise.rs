//! Source-level advice shares the Ruby discovery and benchmark tools.
use std::process::Command;

pub fn cli(args: &[String]) -> Result<(), String> {
    let script = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("bench/advise.rb");
    let status = Command::new("ruby").arg(script).args(args).status()
        .map_err(|e| format!("advise: {e}"))?;
    if status.success() { Ok(()) } else { Err(format!("advise failed ({status}); no speed claim")) }
}
