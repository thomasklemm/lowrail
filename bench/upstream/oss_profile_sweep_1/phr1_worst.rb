# PHR1's slowest inputs: every env key is as long as a normalized target name (20 or 25 characters for
# X-POSTHOG-SESSION-ID), so the branch skips none and only adds its checks; and every key non-ASCII, which the branch
# always normalizes. 73 keys each, as in phr1_body.rb's Rails env.
require "rails"
require "posthog/rails"

tracing = PostHog::Rails.const_get(:TracingHeaders)
same_length = (1..73).to_h { |i| [format("HTTP_X_HEADER_%06d", i).ljust(i.odd? ? 20 : 25, "X"), "v"] }
non_ascii = (1..73).to_h { |i| [format("HTTP_X_HÉADER_%03d", i), "v"] }
raise unless same_length.keys.all? { [20, 25].include?(_1.length) }

UpstreamBench.report("every key a target length") { tracing.extract_header(same_length, "X-POSTHOG-SESSION-ID") }
UpstreamBench.report("every key non-ASCII") { tracing.extract_header(non_ascii, "X-POSTHOG-SESSION-ID") }
