# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 7115.2 / 7109.8, head 7106.5 / 7122.0.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| job line | `RAILS/activesupport/lib/active_support/core_ext/date/calculations.rb:156` | 5.6 | 6.91 | +1.31 | 1.0 |

## Improvements: 0

None.

Not compared: 69 actions (67 no warm value, 2 no warm value in the A/A report).
