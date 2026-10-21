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

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct SqlVariant {
    pub digest: String,
    pub count: u64,
    pub evidence: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct SqlEntry {
    pub test: String,
    /// Exact query identity explaining the branch, not a wildcard matcher.
    /// Admission uses the complete ordered own-thread trace, not this line.
    pub identity: String,
    pub origin: String,
    pub variants: Vec<SqlVariant>,
}

impl SqlEntry {
    pub fn allows(&self, trace: &(String, u64)) -> bool {
        self.variants.iter().any(|v| v.digest == trace.0 && v.count == trace.1)
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Rng {
    pub name: String,
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
    #[serde(default)]
    sql_entries: Vec<SqlEntry>,
    #[serde(default)]
    rng_sources: Vec<Rng>,
}

#[derive(Default)]
pub struct Pinned {
    pub loads: BTreeMap<String, Entry>,
    pub sql: BTreeMap<String, SqlEntry>,
    pub rng_sources: Vec<Rng>,
}

pub fn load(app: &Path, path: &Path) -> Result<Pinned, String> {
    let data = std::fs::read(path).map_err(|e| format!("load controls {}: {e}", path.display()))?;
    let controls: Controls = serde_json::from_slice(&data).map_err(|e| format!("load controls {}: {e}", path.display()))?;
    if controls.format != 1 {
        return Err(format!("unsupported load controls format {}", controls.format));
    }
    let head = Command::new("git").args(["rev-parse", "HEAD"]).current_dir(app).output()
        .map_err(|e| format!("load controls source revision: {e}"))?;
    if !head.status.success() || String::from_utf8_lossy(&head.stdout).trim() != controls.source_revision {
        eprintln!("load controls inactive: source revision mismatch ({})", path.display());
        return Ok(Pinned::default());
    }
    // Match the lock Bundler will actually use, including corpus dependency
    // overlays outside the unchanged app. Relative BUNDLE_GEMFILE paths are
    // relative to the child suite's working directory (the app).
    let gemfile = app.join(std::env::var_os("BUNDLE_GEMFILE").unwrap_or_else(|| "Gemfile".into()));
    let lock_path = if gemfile.file_name().is_some_and(|name| name == "gems.rb") {
        gemfile.with_file_name("gems.locked")
    } else {
        let mut name = gemfile.into_os_string();
        name.push(".lock");
        name.into()
    };
    let lock = std::fs::read(lock_path).map_err(|e| format!("load controls Gemfile.lock: {e}"))?;
    if format!("{:x}", Sha256::digest(lock)) != controls.lock_sha256 {
        eprintln!("load controls inactive: Gemfile.lock SHA256 mismatch ({})", path.display());
        return Ok(Pinned::default());
    }
    // Corpus dependency overlays may change these three metadata files, but
    // changed tracked app code is not the source revision that was proved.
    let clean = Command::new("git").args(["diff", "--quiet", "HEAD", "--", ".",
        ":(exclude)Gemfile", ":(exclude)Gemfile.lock", ":(exclude).ruby-version"])
        .current_dir(app).status().map_err(|e| format!("load controls source check: {e}"))?;
    if !clean.success() {
        eprintln!("load controls inactive: tracked app source differs from revision ({})", path.display());
        return Ok(Pinned::default());
    }
    let mut pinned = Pinned::default();
    for entry in controls.entries {
        let parts: Vec<_> = entry.identity.split('\t').collect();
        if parts.len() != 6 || !matches!(parts[0], "first_test" | "after_suite") || parts[1] != "load_events"
            || parts[2].parse::<usize>().is_err() || !matches!(parts[3], "hook" | "load")
            || parts[4].is_empty() || parts[5].is_empty() || entry.origin.trim().is_empty() || entry.evidence.trim().is_empty()
        {
            return Err(format!("invalid exact load control: {}", entry.identity));
        }
        check_evidence(path, &entry.evidence)?;
        if pinned.loads.insert(entry.identity.clone(), entry).is_some() {
            return Err("duplicate load control identity".into());
        }
    }
    for entry in controls.sql_entries {
        if entry.test.trim().is_empty() || entry.identity.trim().is_empty() || entry.origin.trim().is_empty()
            || entry.variants.len() < 2 {
            return Err(format!("invalid SQL control: {}", entry.test));
        }
        let mut variants = std::collections::BTreeSet::new();
        for variant in &entry.variants {
            if variant.digest.len() != 64 || !variant.digest.bytes().all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
                || !variants.insert((&variant.digest, variant.count)) {
                return Err(format!("invalid or duplicate SQL variant: {}", entry.test));
            }
            check_evidence(path, &variant.evidence)?;
        }
        if pinned.sql.insert(entry.test.clone(), entry).is_some() {
            return Err("duplicate SQL control test".into());
        }
    }
    let mut names = std::collections::BTreeSet::new();
    for rng in controls.rng_sources {
        if !matches!(rng.name.as_str(), "Kernel" | "FFaker::Random")
            || rng.origin.trim().is_empty() || !names.insert(rng.name.clone()) {
            return Err(format!("invalid or duplicate RNG source: {}", rng.name));
        }
        check_evidence(path, &rng.evidence)?;
        pinned.rng_sources.push(rng);
    }
    if !pinned.rng_sources.is_empty() && !names.contains("Kernel") {
        return Err("companion RNG sources must declare Kernel".into());
    }
    Ok(pinned)
}

fn check_evidence(path: &Path, evidence: &str) -> Result<(), String> {
    let file = evidence.split('#').next().unwrap();
    if file.trim().is_empty() || !path.parent().unwrap_or(Path::new(".")).join(file).is_file() {
        return Err(format!("control evidence missing: {evidence}"));
    }
    Ok(())
}
