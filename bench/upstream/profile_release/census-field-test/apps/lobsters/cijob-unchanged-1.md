# lowrail-profile compare

Base: `bundle exec rspec --seed 1234 --format documentation`. Head: `bundle exec rspec --seed 1234 --format documentation`.

Objects per request (all, by run): base 4505.5 / 4504.4, head 4504.4 / 4505.5.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 48 actions (48 no warm value).
