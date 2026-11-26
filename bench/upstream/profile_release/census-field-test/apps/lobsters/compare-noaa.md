# lowrail-profile compare

Base: `bundle exec rspec --seed 1234 --format documentation`. Head: `bundle exec rspec --seed 1234 --format documentation`.

Objects per request (all, by run): base 4505.5 / 4504.4, head 4504.4 / 4505.5.

A change counts when it exceeds the noise floor: twice the larger run-to-run spread in either report and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 48 actions (48 no warm value).
