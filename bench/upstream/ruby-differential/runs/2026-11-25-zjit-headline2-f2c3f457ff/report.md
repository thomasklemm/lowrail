# 2026-11-25-zjit-headline2-f2c3f457ff: 10 run(s) with new differences

Compared with no earlier run of this series and known.json.

* **casa zjit**: 2270 new (2270 differ in all; 2243 TypeError, 14 RSpec::Expectations::ExpectationNotMetError, 11 RSpec::Core::MultipleExceptionError)
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:2:2:1]`
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:2:3:1]`
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:2:4:1]`
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:2:5:1]`
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:3:1:1]`
* **casa zjit1**: 2271 new (2271 differ in all; 2244 TypeError, 14 RSpec::Expectations::ExpectationNotMetError, 11 RSpec::Core::MultipleExceptionError)
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:2:1:1]`
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:2:2:1]`
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:2:3:1]`
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:2:4:1]`
  * `./spec/callbacks/case_contact_metadata_callback_spec.rb[1:1:2:5:1]`
* **discourse zjit**: 16768 new (16769 differ in all; 9125 TypeError, 7538 NoMethodError, 59 RSpec::Core::MultipleExceptionError)
  * `./spec/models/about_spec.rb[1:3:1]`: alone interp pass/pass/pass; zjit fail:TypeError/fail:TypeError/fail:TypeError; zjit1 fail:TypeError/fail:TypeError/fail:TypeError
  * `./spec/models/about_spec.rb[1:3:2]`: alone interp pass/pass/pass; zjit fail:TypeError/fail:TypeError/fail:TypeError; zjit1 fail:TypeError/fail:TypeError/fail:TypeError
  * `./spec/models/about_spec.rb[1:3:3]`: alone interp pass/pass/pass; zjit fail:TypeError/fail:TypeError/fail:TypeError; zjit1 fail:TypeError/fail:TypeError/fail:TypeError
  * `./spec/models/about_spec.rb[1:4:1:1]`: alone interp pass/pass/pass; zjit fail:TypeError/fail:TypeError/fail:TypeError; zjit1 fail:TypeError/fail:TypeError/fail:TypeError
  * `./spec/models/about_spec.rb[1:4:1:2]`: alone interp pass/pass/pass; zjit fail:TypeError/fail:TypeError/fail:TypeError; zjit1 fail:TypeError/fail:TypeError/fail:TypeError
* **hackatime zjit**: 625 new (625 differ in all; 622 TypeError, 3 Minitest::Assertion)
  * `DashboardStatsTest#test_stale_rollup_fingerprint_serves_last_rollup_and_schedules_a_refresh`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `DashboardStatsTest#test_filtered_duration_timeline_excludes_archived_deleted_and_other_users_heartbeats`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `DashboardStatsTest#test_selected_periods_include_average_coding_time_per_elapsed_day`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `DashboardStatsTest#test_until-only_period_average_starts_at_first_heartbeat_matching_dashboard_filters`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `DashboardStatsTest#test_top_operating_system_uses_the_same_display_buckets_as_operating_system_stats`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
* **hackatime zjit1**: 630 new (630 differ in all; 627 TypeError, 3 Minitest::Assertion)
  * `DashboardStatsTest#test_selecting_a_remapped_editor_filter_value_matches_the_underlying_raw_rows`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `DashboardStatsTest#test_project_grouped_durations_preserve_nil_project_values`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `DashboardStatsTest#test_missing_today_stats_and_activity_graph_rollups_recalculate_only_those_fragments_and_schedule_one_refresh`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `DashboardStatsTest#test_coding_category_meter_data_remains_available_for_a_singular_category_filter`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 pass/pass/pass
  * `DashboardStatsTest#test_stale_rollup_fingerprint_serves_last_rollup_and_schedules_a_refresh`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
* **loomio zjit**: 2195 new (2195 differ in all; 2190 TypeError, 5 Minitest::Assertion)
  * `VoteReplyVisibilityTest#test_until-closed_stance_replies_preserve_group_and_direct_topic_access_after_closing`: alone interp pass/pass/pass; zjit error:TypeError/error:TypeError/error:TypeError; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `VoteReplyVisibilityTest#test_a_cached_poll_result_setting_cannot_authorize_a_stance_reply_after_the_setting_changes`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `VoteReplyVisibilityTest#test_existing_vote_replies_load_normally_while_exports_wait_until_closing`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `VoteReplyVisibilityTest#test_group_and_direct_vote_replies_follow_topic_access_regardless_of_voting`: alone interp pass/pass/pass; zjit error:TypeError/error:TypeError/error:TypeError; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `TagDestroyServiceTest#test_removes_legacy_tag_metadata_with_unnormalized_whitespace`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
* **loomio zjit1**: 2196 new (2196 differ in all; 2191 TypeError, 5 Minitest::Assertion)
  * `VoteReplyVisibilityTest#test_public_until-closed_polls_refuse_vote_replies_and_exports_until_closing`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `VoteReplyVisibilityTest#test_until-closed_stance_replies_preserve_group_and_direct_topic_access_after_closing`: alone interp pass/pass/pass; zjit error:TypeError/error:TypeError/error:TypeError; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `VoteReplyVisibilityTest#test_a_cached_poll_result_setting_cannot_authorize_a_stance_reply_after_the_setting_changes`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `VoteReplyVisibilityTest#test_existing_vote_replies_load_normally_while_exports_wait_until_closing`: alone interp pass/pass/pass; zjit pass/pass/pass; zjit1 error:TypeError/error:TypeError/error:TypeError
  * `VoteReplyVisibilityTest#test_group_and_direct_vote_replies_follow_topic_access_regardless_of_voting`: alone interp pass/pass/pass; zjit error:TypeError/error:TypeError/error:TypeError; zjit1 error:TypeError/error:TypeError/error:TypeError
* **mastodon zjit**: 7748 new (7748 differ in all; )
  * `./spec/chewy/accounts_index_spec.rb[1:2:1]`
  * `./spec/chewy/instances_index_spec.rb[1:2:1]`
  * `./spec/chewy/public_statuses_index_spec.rb[1:2:1]`
  * `./spec/chewy/statuses_index_spec.rb[1:2:1]`
  * `./spec/chewy/tags_index_spec.rb[1:2:1]`
* **sure zjit**: 1 new (no outcomes differ in all; )
  * `(no outcomes)`
* **sure zjit1**: 1 new (no outcomes differ in all; )
  * `(no outcomes)`

| App | Mode | Tests | Differ | Seconds |
| --- | --- | ---: | ---: | ---: |
| campfire | interp | 634 | 0 | 32 |
| campfire | yjit | 634 | 0 | 33 |
| campfire | zjit | 634 | 0 | 41 |
| campfire | zjit1 | 634 | 0 | 46 |
| casa | interp | 2992 | 0 | 124 |
| casa | yjit | 2992 | 0 | 110 |
| casa | zjit | 2992 | 2270 | 42 |
| casa | zjit1 | 2992 | 2271 | 44 |
| codetriage | interp | 219 | 0 | 9 |
| codetriage | yjit | 219 | 0 | 9 |
| codetriage | zjit | 219 | 0 | 11 |
| codetriage | zjit1 | 219 | 0 | 13 |
| discourse | interp | 22128 | 0 | 3140 |
| discourse | yjit | 22128 | 0 | 2989 |
| discourse | zjit | 22126 | 16769 | 526 |
| discourse | zjit1 | 22128 | 0 | 3256 |
| fizzy | interp | 1787 | 0 | 81 |
| fizzy | yjit | 1787 | 0 | 67 |
| fizzy | zjit | 1787 | 0 | 79 |
| fizzy | zjit1 | 1787 | 0 | 95 |
| hackatime | interp | 794 | 0 | 47 |
| hackatime | yjit | 794 | 0 | 41 |
| hackatime | zjit | 794 | 625 | 13 |
| hackatime | zjit1 | 794 | 630 | 16 |
| loomio | interp | 3660 | 0 | 535 |
| loomio | yjit | 3660 | 0 | 441 |
| loomio | zjit | 3660 | 2195 | 203 |
| loomio | zjit1 | 3660 | 2196 | 201 |
| mastodon | interp | 7748 | 0 | 584 |
| mastodon | yjit | 7748 | 0 | 523 |
| mastodon | zjit | 0 | 7748 | 17 |
| mastodon | zjit1 | 7748 | 0 | 631 |
| sure | interp | 14236 | 0 | 929 |
| sure | yjit | 14236 | 0 | 801 |
| sure | zjit |  | no outcomes | 3680 |
| sure | zjit1 |  | no outcomes | 4213 |
| writebook | interp | 310 | 0 | 44 |
| writebook | yjit | 310 | 0 | 44 |
| writebook | zjit | 310 | 0 | 51 |
| writebook | zjit1 | 310 | 0 | 58 |
