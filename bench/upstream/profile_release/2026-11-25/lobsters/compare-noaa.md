# lowrail-profile compare

Base: `bundle exec rspec --seed 1234 --format documentation`. Head: `bundle exec rspec --seed 1234 --format documentation`.

Objects per request (all, by run): base 4459.4 / 4457.9, head 4459.6 / 4459.2.

A change counts when it exceeds the noise floor: for a line the larger run-to-run spread in either report and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request, job, mail.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 0

None.

## Improvements: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | InvitationsController#create | 4123.0 | 4087.5 | -35.50 | 20.0 |

Not compared: 48 actions (48 no warm value).
