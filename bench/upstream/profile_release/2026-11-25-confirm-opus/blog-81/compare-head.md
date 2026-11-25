# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 4728.7 / 4726.7, head 4727.7 / 4728.1.

A change counts when it exceeds the noise floor: for a line the base's run-to-run spread across the A/A pair, or head's own if larger, and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 6 actions (6 no warm value).
