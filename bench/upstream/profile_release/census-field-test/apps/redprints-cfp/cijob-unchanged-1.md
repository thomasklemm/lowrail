# lowrail-profile compare

Base: `bundle exec rspec spec --exclude-pattern spec/system/**/*_spec.rb --seed 1234 --format documentation`. Head: `bundle exec rspec spec --exclude-pattern spec/system/**/*_spec.rb --seed 1234 --format documentation`.

Objects per request (all, by run): base 2538.7 / 2540.4, head 2540.4 / 2541.2.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, mail.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 8 actions (8 no warm value).
