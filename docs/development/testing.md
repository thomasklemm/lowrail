# Full test gates and prerequisite coverage

Run full gem gates with **`LOWRAIL_STRICT_GATES=1`**. Missing local tooling or
development gems then fail the affected test instead of silently skipping it.
Without strict mode, partial developer runs may skip those prerequisites.
Every run prints a **Lowrail gate summary** listing each skipped test's full
class/method name and reason, even without `--verbose`, on Minitest 5 and 6.
An optional skip is not coverage of that integration.

From the repository root, build the current CLI and run Rust tests first:

```sh
mise exec -- cargo build --locked
mise exec -- cargo test --locked
```

From `gem/`, run both complete suites, without test filters:

```sh
LOWRAIL_STRICT_GATES=1 mise exec -- rake test TESTOPTS='--verbose --seed=1729'
LOWRAIL_STRICT_GATES=1 mise exec ruby@4.1.0-preview1 -- rake test TESTOPTS='--verbose --seed=1729'
```

Use `--seed=1729`, not a separate seed argument, with Rake's test loader.
Keep the command, Ruby version, exact commit, counts, **named skips**, and
failures with gate evidence. Rebase before publication and rerun affected
gates on the rebased head; an older green summary is not current coverage.

## Preparing prerequisites

Install dependencies for **each** Ruby, not just the primary installation.
The local integration tests require Rails/Active Record 8.1.4, sqlite3, bcrypt,
prism, bootsnap, require-hooks, freezolite, Rack, RSpec and minitest-mock.
The Inertia matrix requires inertia_rails **3.21.2, 3.22.0 and 3.23.0**;
the public analogues also need vite_ruby **3.11.1** and rails_vite **0.3.0**.
The digest fixture pins **digest 3.2.1** for positive coverage: a newer,
uncertified Digest implementation must still refuse, not lose its guard.
Install **Prism 2.0.0** and **sorbet-runtime 0.5.12435** from the gemspec's
development dependencies, plus **Prism 1.4.0** and **minitest 5.27.0** for
the deliberately older locked-parser regression. `minitest-mock 5.27.0`
is a different gem; it does not install Minitest 5. The main runner can use
Minitest 6 (which resolves Prism 1.x); do not force Prism 2 into that runner.
Unbundled test fixtures load their runner first so Rails cannot select an
incompatible Prism independently of Minitest.

The verification-test certificate's positive fixture requires **Bootsnap
1.26.0**. Its compiler-policy certificate intentionally refuses the older
1.18.6 API (`verification_bootsnap_compiler_unknown`); the ordinary loader
matrix still exercises 1.18.6 when installed. Do not relax that certificate.
The fixture Gemfile and individual scenarios are the version constraints.
Tests never install gems or fetch apps automatically.

For the primary Ruby, install the local prerequisites explicitly:

```sh
mise exec ruby@4.0.7 -- gem install rails -v 8.1.4 --no-document
mise exec ruby@4.0.7 -- gem install sqlite3 bcrypt require-hooks freezolite rspec --no-document
mise exec ruby@4.0.7 -- gem install bootsnap -v 1.26.0 --no-document
mise exec ruby@4.0.7 -- gem install prism -v 2.0.0 --no-document
mise exec ruby@4.0.7 -- gem install prism -v 1.4.0 --no-document
mise exec ruby@4.0.7 -- gem install sorbet-runtime -v 0.5.12435 --no-document
mise exec ruby@4.0.7 -- gem install minitest -v 5.27.0 --no-document
mise exec ruby@4.0.7 -- gem install minitest-mock -v 5.27.0 --no-document
for version in 3.21.2 3.22.0 3.23.0; do
  mise exec ruby@4.0.7 -- gem install inertia_rails -v "$version" --no-document
done
mise exec ruby@4.0.7 -- gem install vite_ruby -v 3.11.1 --no-document
mise exec ruby@4.0.7 -- gem install rails_vite -v 0.3.0 --no-document
```

Public build tests use `target/debug/lowrail`, not a separately built release
binary. If it is absent, they run `cargo build --locked`; a failed build is
a failure in either mode, while absent Cargo follows strict prerequisite
handling. Build explicitly before full gates to avoid using a stale binary.
Repository fixtures are copied into disposable directories. The sealed form
test creates its own production schema and rows there, without depending on
or modifying a developer's corpus production database.

**The four `real-blog` gates are required in strict mode.** Prepare them from
the repository root with:

```sh
bash script/corpus real-blog
```

This fetches the pinned Roundhouse generator, generates a Rails 8.1.4 blog,
installs its bundle and prepares its database. In the prepared orb it took
about **28 seconds**, so its absence is not an expensive-setup exemption.
The separate `real-blog-r4` used by sealed experiments does not satisfy the
`real-blog` test path. Missing source/lock/bundle and `LOWRAIL_REAL_BLOG=0`
fail these strict gates; ordinary partial runs can still skip them by name.
Install the generated bundle for each Ruby being tested, in a disposable
copy if its platform lock needs adjustment.

**Ruby 4.0.7 sealed/render-certificate gates also require the retained
`real-blog-r4` specimen**, not a fresh generation under that dirname:

```sh
bash script/corpus real-blog-r4
```

This extracts `fixtures/corpus/real-blog-r4-retained.tgz`, installs the
frozen bundle and prepares a disposable test database. The 50,425-byte
archive is the previously certified source, not a newly approved baseline:
SHA256 `b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99`,
recovered from the [retained-fixture handoff](https://ampcode.com/threads/T-01a1601b-6c5e-77de-8689-b5d8f057ca42).
It contains app/support source, the original lock and `runtime-pins.json`;
no credentials, keys, `.kamal`, storage, databases, logs or caches. The helper
extracts only the app. Production gates create their own schema/rows/seed.

Source SHA256 remains
`86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`,
and lock SHA256 remains
`570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.
The existing entropy validator checks these and every runtime/site pin
unchanged. Fresh generation changes migration filenames/schema timestamps
and app-name-bearing source; updating those pins would certify a different
specimen. An existing mismatched directory is refused, never overwritten:
preserve it and prepare a new DIRNAME, then use `LOWRAIL_TEST_CORPUS_ROOT`
to select a corpus tree containing both required blogs. `--source-only`
extracts/checks retained source and lock without installing the bundle.

Other external apps/checkouts remain optional. Prepare them with
`script/corpus` and `script/rails-suite` when their coverage is required. Use
`LOWRAIL_TEST_CORPUS_ROOT` and `LOWRAIL_RAILS_CHECKOUT` for prepared copies.
An app that is present but fails boot/tests is **not** converted into a skip
(an unavailable real-blog bundle is a missing required prerequisite).
For a preview Ruby whose native gems are unavailable as binary packages,
prepare a disposable corpus copy and build its native gems from source;
do not rewrite the primary corpus locks. Prefer per-gem
`force_ruby_platform: true` for sqlite3/nokogiri/ffi over global
`BUNDLE_FORCE_RUBY_PLATFORM`, which also selects a Tailwind gem without its
platform executable.

## Inventory: required local prerequisite gates

All names below are in `gem/test/`. Missing prerequisites use
`LowrailTest#missing_prerequisite`: a named skip normally, a failure in strict
mode. CLI prerequisites are built automatically as described above.

| Test(s) | Missing prerequisite / reason |
|---|---|
| `ARGuardTest#test_epochs` | Active Record 8.1.4 / sqlite3 |
| `ARInstantiateTest#test_real_loading_matches_rails_across_mutation_and_overrides`; `#test_early_setup_preserves_locale_and_lazy_model_loading` | Rails / sqlite3 / bcrypt |
| `ARPlansTest#test_scoped_reader_preserves_rows_events_and_runtime_changes` | Rails / sqlite3 / bcrypt |
| `CompilerTest#test_public_build_keeps_boot_output_out_of_oracle_protocol` | Debug CLI; Rails / sqlite3 / bcrypt |
| `CompilerTest#test_sealed_build_respects_the_app_locked_prism_grammar` | Debug CLI; Rails / sqlite3 / bcrypt; Prism 1.4.0 and minitest 5.27.0 |
| `DigestMemoTest#test_public_lazy_version_fixture_is_sealed_only_and_test_mode_stays_original` | Debug CLI; rails, rails_vite, inertia_rails or vite_ruby (names reported individually); other locked dependencies fail bundle preparation |
| `E2ETest#test_late_rails_yjit_enable_reports_drift_and_keeps_fact_checks` | railties |
| `E2ETest#test_fast_path_stub_and_restore` | minitest/mock (minitest-mock on Minitest 6) |
| `E2ETest#test_real_blog_outcomes_identical_with_hooks` | `real-blog` source/bundle for the running Ruby; also fails strict mode if disabled with `LOWRAIL_REAL_BLOG=0` |
| `FactsRealBlogTest#test_rails_sections`; `#test_templates`; `#test_app_methods` | `real-blog/Gemfile.lock` and working bundle (`bash script/corpus real-blog`) |
| `FactsTest#test_sorbet_registry_does_not_execute_pending_sigs_or_app_methods` | sorbet-runtime 0.5.12435 |
| `InertiaConfigTest#test_binding_contract_across_supported_gems` | inertia_rails 3.21.2 / 3.22.0 / 3.23.0; missing versions listed |
| `InertiaConfigTest#test_plain_and_stale_build_controls`; `#test_private_binding_and_overridden_schema_are_not_installed` | inertia_rails 3.23.0 |
| `InertiaPropsTest#test_public_contract_and_every_post_entry_dispatch_boundary`; `#test_each_mutation_private_visibility_and_stale_fallback`; `#test_nonmain_ractor_keeps_the_original_resolver` | inertia_rails 3.21.2 / 3.22.0 / 3.23.0; missing versions listed |
| `JitDiagnosticsTest#test_request_only_targeted_tracing_is_not_mislabeled_as_global` | Rack |
| `LoadHooksTest#test_bootstrap_and_targeted_completion_preserve_lazy_loading_and_jit_returns` | Rails / sqlite3 / bcrypt |
| `LoaderTest#test_composes_with_bootsnap_in_both_orders` | bootsnap |
| `LoaderTest#test_freezolite_and_bootsnap_in_every_order_with_cold_and_warm_caches`; `#test_source_transforms_are_not_bypassed` | freezolite / require-hooks |
| `LoaderTest#test_load_iseq_state_matches_off_during_build_and_cold_and_warm_delivery`; `#test_cached_hijacks_do_not_inherit_bootsnap_compiler_options` | require-hooks / bootsnap |
| `MaterializeTest#test_steps_run_in_order_with_deltas`; `#test_model_surface`; `#test_templates_are_compiled_and_linked_to_their_script`; `#test_generated_scripts_cover_attribute_methods` | Rails / sqlite3 / bcrypt (setup) |
| `MemoTest#test_passive_rspec_reporter_keeps_its_lifecycle_without_hiding_other_tracing` | rspec-core |
| `MemoTest#test_public_inertia_vite_version_keeps_its_own_file_and_time_semantics` | vite_ruby 3.11.1 / inertia_rails 3.23.0 |
| `MinitestPluginTest#test_opt_in_load_census_observes_but_never_forces_autoloads` | Rails / sqlite3 / bcrypt |
| `MinitestPluginTest#test_rails_parallel_workers` | Active Support parallelization |
| `ObserveTest#test_suite_passes_with_recorder`; `#test_definitions_after_boot`; `#test_type_samples_are_bounded`; `#test_lightweight_types_only_run_preserves_samples_and_outcomes` | Rails / sqlite3 / bcrypt (setup) |
| `PreloadPlansTest#test_plans_keep_rails_results_and_invalidate`; `#test_preexisting_preloader_wrappers_are_not_bypassed` | Active Record 8.1.4 / sqlite3 |
| `PreloadPlansTest#test_inherited_singleton_getter_fact_names_its_real_owner` | Rails / sqlite3 / bcrypt |
| `RSpecReporterTest#test_rubyopt_outcomes_with_and_without_lowering` | rspec-core |
| `SealedLinkTest#test_cold_opt_in_delivery_preserves_response_effects_and_refuses_foreign_receivers` | On Ruby 4.0.7: debug CLI; Rails / sqlite3 / bcrypt |
| `SqlTraceTest#test_trace_detects_changed_queries_not_bind_values`; `#test_full_trace_lines`; `#test_disabled` | Active Record 8.1.4 / sqlite3 |
| `SuppressedHooksTest#test_old_guarded_artifacts_follow_suppressed_mutations_and_production_sealed_units_hit` | Rails / sqlite3 / bcrypt / inertia_rails 3.23.0 |
| `TestCertificateTest#test_natural_generation_releases_pending_once_and_live_resets_do_not_retire`; `#test_real_config_builder_bootsnap_and_method_mutations_retire_stickily`; `#test_active_parent_forks_original_child_with_no_inherited_authority_or_counters`; `#test_actual_parallel_policy_mismatch_refuses_despite_workers1` | Rails / sqlite3 / bcrypt; Bootsnap 1.26.0 compiler API |
| `TestCertificateTest#test_render_missing_or_mismatched_view_context_certificate_stays_original`; `#test_render_mutation_and_fork_authority_are_sticky_and_unit_local`; `#test_render_name_and_tag_dispatch_bypass_existing_view_reflection` | On Ruby 4.0.7: retained `real-blog-r4` source/bundle and debug CLI |
| `BlogProductionTest#test_cold_sealed_admission_does_not_prepare_the_app`; `#test_terminal_completion_distinguishes_pending_jobs_from_drained_cable` | Retained `real-blog-r4` source/bundle and debug CLI; entropy companions require its unchanged source/lock/runtime pins |
| `ViewTest#test_default_link_to_observes_a_suppressed_redefinition_after_warmup`; `#test_name_expression_can_change_the_actual_builder_before_link_to`; `#test_to_param_can_change_the_actual_route_formatter_without_replaying_conversion` | Debug CLI; Rails / sqlite3 / bcrypt |
| `FormScaffoldTest#test_public_sealed_build_preserves_forms_observers_and_refuses_custom_builder`; `#test_passive_production_token_and_collection_public_artifact` | On Ruby 4.0.7: retained `real-blog-r4` source/bundle and debug CLI; production schema/rows prepared in the test copy |

## Inventory: intentional optional skips (also named in strict mode)

| Test(s) | Reason |
|---|---|
| `MaterializeCorpusTest#test_real_blog`; `#test_campfire` | Corresponding `real-blog-r4` / `campfire` corpus lock absent |
| `ObserveCorpusTest#test_real_blog_suite` | `real-blog-r4/Gemfile.lock` absent |
| `RailsSuiteReportTest#test_separate_build_does_not_change_view_primary_key_results` | Rails checkout `RAILS_VERSION` absent (`script/rails-suite`) |
| `RailsSuiteReportTest#test_profiling_preserves_backtrace_cleaner_results` | Rails checkout or prepared `.lowrail/rails-suite/Gemfile` absent |
| `SealedLinkTest#test_cold_opt_in_delivery_preserves_response_effects_and_refuses_foreign_receivers` | Fixture is certified only on Ruby 4.0.7; other Ruby version printed |
| `FormScaffoldTest#test_public_sealed_build_preserves_forms_observers_and_refuses_custom_builder`; `#test_passive_production_token_and_collection_public_artifact`; `BlogProductionTest#test_cold_sealed_admission_does_not_prepare_the_app` | Same Ruby 4.0.7 boundary |

Although the two blog corpus observer tests can individually skip when
`real-blog-r4` is absent, that absence does not exempt the required sealed
gates above from strict-mode failure.

Skips/pending examples inside the Minitest and RSpec reporter **fixture
suites** intentionally test outcome reporting. They are not missing gem-test
prerequisites or exceptions to strict mode. `TestHelperTest` similarly proves
the normal/strict failure and optional-skip contracts in child suites.
