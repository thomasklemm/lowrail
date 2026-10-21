//! Reviewed, app-pinned off/off evidence, never a wildcard suppression list.
use std::collections::BTreeMap;
use std::path::Path;
use std::process::Command;

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Entry {
    pub identity: String,
    pub evidence: String,
    pub origin: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Controls {
    format: u32,
    source_revision: String,
    lock_sha256: String,
    entries: Vec<Entry>,
}

pub fn load(app: &Path, path: &Path) -> Result<BTreeMap<String, Entry>, String> {
    let data = std::fs::read(path).map_err(|e| format!("load controls {}: {e}", path.display()))?;
    let controls: Controls = serde_json::from_slice(&data).map_err(|e| format!("load controls {}: {e}", path.display()))?;
    if controls.format != 1 {
        return Err(format!("unsupported load controls format {}", controls.format));
    }
    let head = Command::new("git").args(["rev-parse", "HEAD"]).current_dir(app).output()
        .map_err(|e| format!("load controls source revision: {e}"))?;
    if !head.status.success() || String::from_utf8_lossy(&head.stdout).trim() != controls.source_revision {
        eprintln!("load controls inactive: source revision mismatch ({})", path.display());
        return Ok(BTreeMap::new());
    }
    let lock = std::fs::read(app.join("Gemfile.lock")).map_err(|e| format!("load controls Gemfile.lock: {e}"))?;
    if format!("{:x}", Sha256::digest(lock)) != controls.lock_sha256 {
        eprintln!("load controls inactive: Gemfile.lock SHA256 mismatch ({})", path.display());
        return Ok(BTreeMap::new());
    }
    // Corpus dependency overlays may change these three metadata files, but
    // changed tracked app code is not the source revision that was proved.
    let clean = Command::new("git").args(["diff", "--quiet", "HEAD", "--", ".",
        ":(exclude)Gemfile", ":(exclude)Gemfile.lock", ":(exclude).ruby-version"])
        .current_dir(app).status().map_err(|e| format!("load controls source check: {e}"))?;
    if !clean.success() {
        eprintln!("load controls inactive: tracked app source differs from revision ({})", path.display());
        return Ok(BTreeMap::new());
    }
    let mut entries = BTreeMap::new();
    for entry in controls.entries {
        let parts: Vec<_> = entry.identity.split('\t').collect();
        if parts.len() != 6 || !matches!(parts[0], "first_test" | "after_suite") || parts[1] != "load_events"
            || parts[2].parse::<usize>().is_err() || !matches!(parts[3], "hook" | "load")
            || parts[4].is_empty() || parts[5].is_empty() || entry.origin.trim().is_empty() || entry.evidence.trim().is_empty()
        {
            return Err(format!("invalid exact load control: {}", entry.identity));
        }
        let file = entry.evidence.split('#').next().unwrap();
        if file.is_empty() || !path.parent().unwrap_or(Path::new(".")).join(file).is_file() {
            return Err(format!("load control evidence missing: {}", entry.evidence));
        }
        if entries.insert(entry.identity.clone(), entry).is_some() {
            return Err("duplicate load control identity".into());
        }
    }
    Ok(entries)
}
