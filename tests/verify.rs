//! Outcome files are the reporter/CLI boundary, independent of a test framework.
use std::process::Command;

#[test]
fn verify_counts_merged_minitest_or_independent_rspec_processes_once() {
    let app = std::env::temp_dir().join(format!("lowrail-verify-{}", std::process::id()));
    std::fs::create_dir_all(&app).unwrap();
    std::fs::create_dir_all(app.join(".lowrail")).unwrap();
    let manifest = serde_json::json!({"units":[{"id":7,"pass":"route/path"},{"id":9,"pass":"view/link_to"}]});
    std::fs::write(app.join(".lowrail/manifest.json"), manifest.to_string()).unwrap();
    for merged in [false, true] {
        let script = r#"
          [ "$LOWRAIL_SHADOW" = strict ] || exit 42
          printf '%s' '{"tests":{"example[1:1]":{"result":"pass"}},"unit_hits":{"7":3},"unit_fallbacks":{"9":4},"ruby":"ruby fixture","jit_diagnostics":[{"pid":1,"counter":11}],"jit_modes":[{"pid":1,"drift":"fixture mode drift"}]}' > "$LOWRAIL_OUTCOMES.1"
          printf '%s' '{"tests":{"example[1:2]":{"result":"skip","failure":"later"}},"unit_hits":{"7":2},"unit_fallbacks":{"9":2},"ruby":"ruby fixture","jit_diagnostics":[{"pid":2,"counter":22}],"jit_modes":[{"pid":2,"drift":null}]}' > "$LOWRAIL_OUTCOMES.2"
          if [ "$1" = true ]; then
            printf '%s' '{"tests":{"example[1:1]":{"result":"pass"},"example[1:2]":{"result":"skip","failure":"later"}},"unit_hits":{"7":5},"unit_fallbacks":{"9":6},"ruby_descriptions":["ruby fixture"],"jit_diagnostics":[{"pid":1,"counter":11},{"pid":2,"counter":22}],"jit_modes":[{"pid":1,"drift":"fixture mode drift"},{"pid":2,"drift":null}]}' > "$LOWRAIL_OUTCOMES"
            # A newer build during execution must not relabel these counters.
            printf '%s' '{"units":[{"id":7,"pass":"different/pass"}]}' > .lowrail/manifest.json
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
        let last: serde_json::Value = serde_json::from_slice(&std::fs::read(app.join(".lowrail/verify/last.json")).unwrap()).unwrap();
        assert_eq!(last["identical"], true);
        assert_eq!(last["manifest"], manifest);
        assert_eq!(last["passes"]["route/path"], serde_json::json!({"hits":5,"fallbacks":0}));
        assert_eq!(last["passes"]["view/link_to"], serde_json::json!({"hits":0,"fallbacks":6}));
        assert_eq!(last["report"]["on"]["ruby_descriptions"], serde_json::json!(["ruby fixture"]));
        let mut snapshots = last["report"]["on"]["jit_diagnostics"].as_array().unwrap().clone();
        snapshots.sort_by_key(|value| value["pid"].as_u64());
        assert_eq!(snapshots, serde_json::json!([{"pid":1,"counter":11},{"pid":2,"counter":22}]).as_array().unwrap().clone());
        assert!(stdout.contains("fixture mode drift"), "{stdout}");
        let mut modes = last["report"]["on"]["jit_modes"].as_array().unwrap().clone();
        modes.sort_by_key(|value| value["pid"].as_u64());
        assert_eq!(modes, serde_json::json!([{"pid":1,"drift":"fixture mode drift"},{"pid":2,"drift":null}]).as_array().unwrap().clone());
    }
    std::fs::remove_dir_all(app).unwrap();
}

/// A trace that differs between two runs of the same mode is noise and must
/// not fail verify; a trace that reproducibly differs only with LOWRAIL=1 must.
#[test]
fn verify_excludes_sql_traces_unstable_between_off_runs() {
    let app = std::env::temp_dir().join(format!("lowrail-verify-sql-{}", std::process::id()));
    std::fs::create_dir_all(&app).unwrap();
    for lowrail_changes_sql in [false, true] {
        let script = r#"
          stable=same; if [ "$1" = true ] && [ "$LOWRAIL" = 1 ]; then stable=changed; fi
          # c varies only in the on runs: two agreeing off runs must not make it count.
          rare=off; if [ "$LOWRAIL" = 1 ]; then rare="on-$$"; fi
          printf '{"tests":{"a":{"result":"pass"},"b":{"result":"pass"},"c":{"result":"pass"}},"processes":[1],"sql":{"a":{"digest":"%s","n":1},"b":{"digest":"noise-%s","n":1},"c":{"digest":"%s","n":1}}}' "$stable" "$$" "$rare" > "$LOWRAIL_OUTCOMES"
        "#;
        let result = Command::new(env!("CARGO_BIN_EXE_lowrail"))
            .arg("verify")
            .arg(&app)
            .args(["--", "sh", "-c", script, "sh", if lowrail_changes_sql { "true" } else { "false" }])
            .output()
            .unwrap();
        let stdout = String::from_utf8_lossy(&result.stdout);
        assert!(stdout.contains("2 tests excluded"), "{stdout}");
        assert_eq!(result.status.success(), !lowrail_changes_sql, "{stdout}");
        assert_eq!(stdout.contains("a: 1 → 1 queries"), lowrail_changes_sql, "{stdout}");
    }
    std::fs::remove_dir_all(app).unwrap();
}

#[test]
fn verify_gates_reproducible_load_changes_and_isolates_the_pass() {
    let app = std::env::temp_dir().join(format!("lowrail-verify-loads-{}", std::process::id()));
    std::fs::create_dir_all(app.join(".lowrail")).unwrap();
    std::fs::write(app.join(".lowrail/manifest.json"), serde_json::json!({"units":[
        {"id":7,"pass":"fixture/quiet"},{"id":9,"pass":"fixture/eager"}]}).to_string()).unwrap();
    for changes_loads in ["none", "pass", "setup"] {
        let script = r#"
          extra=''
          case ",${LOWRAIL_UNITS-7,9}," in
            *,9,*) if [ "$LOWRAIL" = 1 ] && [ "$1" = pass ]; then extra=',"App::Early"'; fi ;;
          esac
          if [ "$LOWRAIL" = 1 ] && [ "$1" = setup ]; then extra=',"App::Early"'; fi
          printf '{"tests":{"a":{"result":"pass"}},"verify_loads":{"snapshot_seconds":0.012,"stages":{"first_test":{"constants":["App::Shared","Noise%s"%s]},"after_suite":{"constants":["App::Shared","App::Early"]}}}}' "$$" "$extra" > "$LOWRAIL_OUTCOMES"
        "#;
        let result = Command::new(env!("CARGO_BIN_EXE_lowrail"))
            .args(["verify", app.to_str().unwrap(), "--", "sh", "-c", script, "sh", changes_loads])
            .output().unwrap();
        let stdout = String::from_utf8_lossy(&result.stdout);
        assert_eq!(result.status.success(), changes_loads == "none", "{stdout}");
        let last: serde_json::Value = serde_json::from_slice(&std::fs::read(app.join(".lowrail/verify/last.json")).unwrap()).unwrap();
        assert!(!last["report"]["unstable_loads"].as_array().unwrap().is_empty());
        if changes_loads != "none" {
            let culprit = if changes_loads == "setup" { "setup/source delivery (no active units)" } else { "fixture/eager" };
            assert_eq!(last["report"]["load_culprit_passes"], serde_json::json!([culprit]));
            assert!(stdout.contains("first_test\tconstants\tApp::Early"), "{stdout}");
        }
    }
    std::fs::remove_dir_all(app).unwrap();
}

#[test]
fn verify_reports_exact_pinned_app_load_controls_without_hiding_other_changes() {
    let app = std::env::temp_dir().join(format!("lowrail-verify-load-controls-{}", std::process::id()));
    std::fs::create_dir_all(app.join(".lowrail")).unwrap();
    std::fs::write(app.join("Gemfile.lock"), "hello").unwrap();
    std::fs::write(app.join("app.rb"), "original").unwrap();
    for args in [vec!["init", "-q"], vec!["add", "Gemfile.lock", "app.rb"], vec!["commit", "-qm", "fixture"]] {
        assert!(Command::new("git").args(args).current_dir(&app)
            .env("GIT_AUTHOR_NAME", "Thomas Klemm").env("GIT_AUTHOR_EMAIL", "github@tklemm.eu")
            .env("GIT_COMMITTER_NAME", "Thomas Klemm").env("GIT_COMMITTER_EMAIL", "github@tklemm.eu")
            .status().unwrap().success());
    }
    let head = Command::new("git").args(["rev-parse", "HEAD"]).current_dir(&app).output().unwrap();
    let revision = String::from_utf8(head.stdout).unwrap().trim().to_string();
    let identity = "after_suite\tload_events\t349\tload\tFixture\tfixture.rb";
    let controls = app.join(".lowrail/load-controls.json");
    std::fs::write(app.join(".lowrail/evidence.json"), "{\"off_off\":true}").unwrap();
    let script = r#"
      events=''; if [ "$LOWRAIL" = 1 ]; then events='"349\tload\tFixture\tfixture.rb"'; fi
      if [ "$LOWRAIL" = 1 ] && [ "$1" = unlisted ]; then events="$events,\"350\\tload\\tUnlisted\\tother.rb\""; fi
      if [ "$LOWRAIL" = 1 ] && [ "$1" = shifted ]; then events='"350\tload\tFixture\tfixture.rb"'; fi
      printf '{"tests":{"a":{"result":"pass"}},"verify_loads":{"stages":{"first_test":{},"after_suite":{"load_events":[%s]}}}}' "$events" > "$LOWRAIL_OUTCOMES"
    "#;
    for case in ["listed", "unlisted", "shifted", "lock", "revision", "dirty"] {
        std::fs::write(app.join("Gemfile.lock"), if case == "lock" { "changed" } else { "hello" }).unwrap();
        std::fs::write(app.join("app.rb"), if case == "dirty" { "changed" } else { "original" }).unwrap();
        std::fs::write(&controls, serde_json::json!({"format":1,
            "source_revision": if case == "revision" { "0000000000000000000000000000000000000000" } else { &revision },
            "lock_sha256":"2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
            "entries":[{"identity":identity,"evidence":"evidence.json#off_off",
                "origin":"background worker versus main thread; fixture control"}]}).to_string()).unwrap();
        let result = Command::new(env!("CARGO_BIN_EXE_lowrail"))
            .args(["verify", app.to_str().unwrap(), "--load-controls", controls.to_str().unwrap(),
                "--", "sh", "-c", script, "sh", case]).output().unwrap();
        let stdout = String::from_utf8_lossy(&result.stdout);
        assert_eq!(result.status.success(), case == "listed", "{case}: {stdout}\n{}", String::from_utf8_lossy(&result.stderr));
        let last: serde_json::Value = serde_json::from_slice(&std::fs::read(app.join(".lowrail/verify/last.json")).unwrap()).unwrap();
        if matches!(case, "listed" | "unlisted" | "shifted") {
            let count = if case == "shifted" { 0 } else { 1 };
            assert!(stdout.contains(&format!("known app nondeterminism: {count} differing load identities")), "{stdout}");
            assert_eq!(last["report"]["known_app_loads"][identity]["origin"], "background worker versus main thread; fixture control");
            if case == "shifted" {
                assert!(stdout.contains("on only: after_suite\tload_events\t350\tload\tFixture"), "{stdout}");
                continue;
            }
            assert!(stdout.contains(identity) && stdout.contains("evidence.json#off_off"), "{stdout}");
            assert!(last["report"]["on"]["loads"].as_array().unwrap().iter().any(|v| v == identity));
            if case == "unlisted" { assert!(stdout.contains("on only: after_suite\tload_events\t350\tload\tUnlisted"), "{stdout}"); }
        } else {
            assert!(last["report"]["known_app_loads"].as_object().unwrap().is_empty());
            assert!(stdout.contains("on only: after_suite\tload_events\t349\tload\tFixture"), "{stdout}");
        }
    }
    std::fs::remove_dir_all(app).unwrap();
}
