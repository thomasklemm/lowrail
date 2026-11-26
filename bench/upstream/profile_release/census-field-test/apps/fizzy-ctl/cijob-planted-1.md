# lowrail-profile compare

Base: `bin/rails test test/controllers -v`. Head: `bin/rails test test/controllers -v`.

Objects per request (all, by run): base 11561.3 / 11560.4, head 11564.2 / 11563.6.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 26 actions (26 no warm value).
