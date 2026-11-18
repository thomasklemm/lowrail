# Lowrail profile compare

Base: `bin/rails test --verbose`. Head: `bin/rails test --verbose`.

Objects per request (all, by run): base 7274.0 / 7274.1, head 7273.4 / 7274.4.

A change counts when it exceeds the noise floor: for a line the larger run-to-run spread in either report and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request, job, mail.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| job action | BackgroundInactiveEmailJob#perform | 75380.0 | 75467.5 | +87.50 | 78.0 |

## Improvements: 0

None.

Not compared: 5 actions (5 no warm value).
