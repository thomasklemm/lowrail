# lowrail-profile compare

Base: `bundle exec rspec --seed 1234 --format documentation`. Head: `bundle exec rspec --seed 1234 --format documentation`.

Objects per request (all, by run): base 4459.4 / 4457.9, head 4467.1 / 4466.8.

A change counts when it exceeds the noise floor: for a line the base's run-to-run spread across the A/A pair, or head's own if larger, and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 3

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | HomeController#index | 4333.3 | 4392.9 | +59.60 | 20.0 |
| request line | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | 33.07 | 35.87 | +2.80 | 1.0 |
| request line | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:15` | 1.28 | 4.08 | +2.80 | 1.0 |

## Improvements: 0

None.

Not compared: 48 actions (48 no warm value).
