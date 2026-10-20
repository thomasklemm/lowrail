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

/// A trace that already differs between two LOWRAIL=0 runs is noise and
/// must not fail verify; a trace that differs only with LOWRAIL=1 must.
#[test]
fn verify_excludes_sql_traces_unstable_between_off_runs() {
    let app = std::env::temp_dir().join(format!("lowrail-verify-sql-{}", std::process::id()));
    std::fs::create_dir_all(&app).unwrap();
    for lowrail_changes_sql in [false, true] {
        let script = r#"
          stable=same; if [ "$1" = true ] && [ "$LOWRAIL" = 1 ]; then stable=changed; fi
          printf '{"tests":{"a":{"result":"pass"},"b":{"result":"pass"}},"processes":[1],"sql":{"a":{"digest":"%s","n":1},"b":{"digest":"noise-%s","n":1}}}' "$stable" "$$" > "$LOWRAIL_OUTCOMES"
        "#;
        let result = Command::new(env!("CARGO_BIN_EXE_lowrail"))
            .arg("verify")
            .arg(&app)
            .args(["--", "sh", "-c", script, "sh", if lowrail_changes_sql { "true" } else { "false" }])
            .output()
            .unwrap();
        let stdout = String::from_utf8_lossy(&result.stdout);
        assert!(stdout.contains("1 tests excluded"), "{stdout}");
        assert_eq!(result.status.success(), !lowrail_changes_sql, "{stdout}");
        assert_eq!(stdout.contains("a: 1 → 1 queries"), lowrail_changes_sql, "{stdout}");
    }
    std::fs::remove_dir_all(app).unwrap();
}
