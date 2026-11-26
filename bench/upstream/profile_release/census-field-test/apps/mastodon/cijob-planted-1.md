# lowrail-profile compare

Base: `bundle exec rspec spec/requests spec/controllers --seed 1234 --format documentation`. Head: `bundle exec rspec spec/requests spec/controllers --seed 1234 --format documentation`.

Objects per request (all, by run): base 8049.8 / 8038.3, head 8031.6 / 8017.7.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 128 actions (128 no warm value).
