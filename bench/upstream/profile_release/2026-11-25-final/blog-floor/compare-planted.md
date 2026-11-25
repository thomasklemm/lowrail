# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 5989.8 / 5985.7, head 6007.5 / 5988.8.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request line | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` | 21.58 | 23.25 | +1.67 | 1.0 |

## Improvements: 0

None.

Not compared: 6 actions (6 no warm value).
