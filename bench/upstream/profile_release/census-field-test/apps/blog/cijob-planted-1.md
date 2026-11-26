# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 4727.3 / 4726.8, head 4745.0 / 4730.7.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request.

## Regressions: 2

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request line | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:15` | 0.17 | 1.83 | +1.67 | 1.0 |
| request line | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | 19.42 | 21.08 | +1.67 | 1.0 |

## Improvements: 0

None.

Not compared: 6 actions (6 no warm value).
