# lowrail-profile compare

Base: `bin/rails test test/controllers -v`. Head: `bin/rails test test/controllers -v`.

Objects per request (all, by run): base 16586.2 / 16586.5, head 16586.2 / 16586.6.

A change counts when it exceeds the noise floor: twice the larger run-to-run spread in either report and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 7 actions (7 no warm value).
