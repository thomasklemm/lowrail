# Lowrail profile compare

Base: `bin/rails test:all -v`. Head: `bin/rails test:all -v`.

Objects per request (all, by run): base 3271.1 / 3270.2, head 3266.2 / 3269.4.

A change counts when it exceeds the noise floor: for a line the larger run-to-run spread in either report and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 11 actions (11 no warm value).
