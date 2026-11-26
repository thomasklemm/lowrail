# lowrail-profile compare

Base: `bundle exec rspec spec/requests spec/controllers --seed 1234 --format documentation`. Head: `bundle exec rspec spec/requests spec/controllers --seed 1234 --format documentation`.

Objects per request (all, by run): base 8049.8 / 8038.3, head 8044.0 / 8031.1.

A change counts when it exceeds the noise floor: twice the larger run-to-run spread in either report and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 128 actions (128 no warm value).
