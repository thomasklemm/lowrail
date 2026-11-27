| App | tests r81 | failing r81 | tests main | failing main | pass r81, fail main | fail r81, pass main |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| hackatime | 789 | 0 | 773 | 0 | 0 | 0 |
| lobsters | 985 | 0 | 985 | 0 | 0 | 0 |
| react-starter-kit | 59 | 0 | 59 | 0 | 0 | 0 |
| redprints-cfp | 70 | 0 | 79 | 0 | 0 | 0 |

## hackatime

No regressions.

Only on r81 (20): Api::Hackatime::V1::HackatimeControllerTest#test_bulk_heartbeat_ignores_unknown_fields_and_preserves_AI_telemetry; Api::Hackatime::V1::HackatimeControllerTest#test_bulk_heartbeat_normalizes_permitted_params; Api::Hackatime::V1::HackatimeControllerTest#test_bulk_heartbeat_reports_non-object_array_items_without_discarding_valid_items; Api::Hackatime::V1::HackatimeControllerTest#test_bulk_heartbeat_resolves_<<LAST_LANGUAGE>>_from_previous_heartbeat_in_same_batch; Api::Hackatime::V1::HackatimeControllerTest#test_bulk_text_plain_heartbeat_rejects_a_non-array_payload; Api::Hackatime::V1::HackatimeControllerTest#test_current_user_returns_a_WakaTime_compatible_profile; Api::Hackatime::V1::HackatimeControllerTest#test_duplicate_heartbeat_with_different_ip_returns_existing_record; Api::Hackatime::V1::HackatimeControllerTest#test_malformed_authorization_header_does_not_fall_through_to_query_API_key; Api::Hackatime::V1::HackatimeControllerTest#test_single_heartbeat_ignores_unknown_fields_and_preserves_AI_telemetry; Api::Hackatime::V1::HackatimeControllerTest#test_single_heartbeat_resolves_<<LAST_LANGUAGE>>_from_existing_heartbeats

## lobsters

No regressions.

## react-starter-kit

No regressions.

## redprints-cfp

No regressions.
