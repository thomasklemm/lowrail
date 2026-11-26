# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 5997.5 / 5993.9, head 5999.6 / 5998.8.

A change counts when it exceeds the noise floor: twice the larger run-to-run spread in either report and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request line | `RUBY/uri/common.rb:394` | 19.25 | 22.13 | +2.88 | 1.0 |

## Improvements: 0

None.

Not compared: 6 actions (6 no warm value).
