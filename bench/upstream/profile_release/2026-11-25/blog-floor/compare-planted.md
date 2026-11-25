# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 5985.4 / 5990.0, head 6014.3 / 5987.3.

A change counts when it exceeds the noise floor: for a line the base's run-to-run spread across the A/A pair, or head's own if larger, and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request line | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` | 21.58 | 23.25 | +1.67 | 1.0 |

## Improvements: 0

None.

Not compared: 6 actions (6 no warm value).
