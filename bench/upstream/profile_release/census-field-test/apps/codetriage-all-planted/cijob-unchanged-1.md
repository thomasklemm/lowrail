# lowrail-profile compare

Base: `bin/rails test --verbose`. Head: `bin/rails test --verbose`.

Objects per request (all, by run): base 5998.0 / 5998.2, head 5997.9 / 5998.9.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 5 actions (5 no warm value).
