# lowrail-profile compare

Base: `bin/rails test --verbose`. Head: `bin/rails test --verbose`.

Objects per request (all, by run): base 5988.2 / 5986.7, head 5997.7 / 5998.4.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 3

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | PagesController#index | 4324.4 | 4363.15 | +38.75 | 20.0 |
| request line | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:15` | 0.3 | 5.31 | +5.01 | 1.0 |
| request line | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | 41.06 | 46.06 | +5.00 | 1.0 |

## Improvements: 0

None.

Not compared: 5 actions (5 no warm value).
