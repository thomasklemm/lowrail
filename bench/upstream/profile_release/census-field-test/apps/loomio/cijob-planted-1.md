# lowrail-profile compare

Base: `bin/rails test test/controllers -v`. Head: `bin/rails test test/controllers -v`.

Objects per request (all, by run): base 16586.2 / 16586.5, head 16586.4 / 16586.5.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 7 actions (7 no warm value).
