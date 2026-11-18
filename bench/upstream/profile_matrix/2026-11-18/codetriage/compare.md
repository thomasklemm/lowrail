# Lowrail profile compare

Base: `bin/rails test --verbose`. Head: `bin/rails test --verbose`.

Objects per request (all, by run): base 7274.0 / 7274.1, head 7273.4 / 7274.4.

A change counts when it exceeds the noise floor: for a line the base's run-to-run spread across the A/A pair, or head's own if larger, and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 5 actions (5 no warm value).
