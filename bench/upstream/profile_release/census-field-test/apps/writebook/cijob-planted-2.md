# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 25019.9 / 25719.9, head 25252.0 / 25806.1.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request line | `RAILS/activerecord/lib/active_record/core.rb:433` | 3.58 | 9.05 | +5.46 | 1.61 |

## Improvements: 0

None.

Not compared: 32 actions (32 no warm value).
