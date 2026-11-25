# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 20923.5 / 20924.1, head 20923.1 / 20924.2.

A change counts when it exceeds the noise floor: for a line the base's run-to-run spread across the A/A pair, or head's own if larger, and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request, job, cable.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 55 actions (55 no warm value).
