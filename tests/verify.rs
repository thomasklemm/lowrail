//! Outcome files are the reporter/CLI boundary, independent of a test framework.
use std::process::Command;

#[test]
fn verify_counts_merged_minitest_or_independent_rspec_processes_once() {
    let app = std::env::temp_dir().join(format!("lowrail-verify-{}", std::process::id()));
    std::fs::create_dir_all(&app).unwrap();
    for merged in [false, true] {
        let script = r#"
          printf '%s' '{"tests":{"example[1:1]":{"result":"pass"}},"unit_hits":{"7":3}}' > "$LOWRAIL_OUTCOMES.1"
          printf '%s' '{"tests":{"example[1:2]":{"result":"skip","failure":"later"}},"unit_hits":{"7":2}}' > "$LOWRAIL_OUTCOMES.2"
          if [ "$1" = true ]; then
            printf '%s' '{"tests":{"example[1:1]":{"result":"pass"},"example[1:2]":{"result":"skip","failure":"later"}},"unit_hits":{"7":5}}' > "$LOWRAIL_OUTCOMES"
          fi
        "#;
        let result = Command::new(env!("CARGO_BIN_EXE_lowrail"))
            .arg("verify")
            .arg(&app)
            .args([
                "--",
                "sh",
                "-c",
                script,
                "sh",
                if merged { "true" } else { "false" },
            ])
            .output()
            .unwrap();
        assert!(
            result.status.success(),
            "{}",
            String::from_utf8_lossy(&result.stderr)
        );
        let stdout = String::from_utf8_lossy(&result.stdout);
        assert!(
            stdout.contains("2 tests, 1 pass, 0 fail, 0 error, 1 skip"),
            "{stdout}"
        );
        assert!(
            stdout.contains("fast-path hits: 5 across 1 units"),
            "{stdout}"
        );
    }
    std::fs::remove_dir_all(app).unwrap();
}
