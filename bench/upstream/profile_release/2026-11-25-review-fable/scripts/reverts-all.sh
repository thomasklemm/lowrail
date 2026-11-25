#!/usr/bin/env bash
r=$1; here=$(dirname "$0")
$here/revert.sh $r 8e36ae06 'test_path_gems_and_an_engine_root_are_classified'
$here/revert.sh $r a4bc8d5a 'test_arguments_after_the_separator_belong_to_the_command'
$here/revert.sh $r dbe31072 'test_processes_the_suite_starts_run_as_without_the_profiler'
$here/revert.sh $r 9683fcf4 'test_processes_the_suite_starts_run_as_without_the_profiler'
$here/revert.sh $r 90ef44e3 'test_runs_are_deleted_after_the_report_unless_kept|test_out_never_clears_a_directory_it_did_not_create'
$here/revert.sh $r 9736c860 'test_timeout_stops_a_hung_run_and_its_processes'
$here/revert.sh $r abf515d3 'test_compare_refuses_captures_of_parallel_workers'
$here/revert.sh $r 1618fc38 'test_compare_floor_terms|test_compare_lists_what_exceeds_the_floor_of_an_a_a_pair|test_documented_ci_compare_step_reports_and_never_fails|test_compare_needs_complete_comparable_captures|test_compare_refuses_captures_of_parallel_workers|test_counts_only_inside_requests_and_attributes_them_to_the_app'
