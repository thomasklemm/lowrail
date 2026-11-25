# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 20923.5 / 20924.1, head 20928.2 / 20928.3.

A change counts when it exceeds the noise floor: for a line the base's run-to-run spread across the A/A pair, or head's own if larger, and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request, job, cable.

## Regressions: 3

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | RoomsController#show | 24520.25 | 24562.3 | +42.05 | 24.56 |
| request line | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` | 104.36 | 106.05 | +1.68 | 1.0 |
| request line | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:17` | 5.94 | 7.59 | +1.65 | 1.0 |

## Improvements: 0

None.

Not compared: 55 actions (55 no warm value).
