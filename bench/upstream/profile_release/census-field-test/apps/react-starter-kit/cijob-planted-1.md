# lowrail-profile compare

Base: `bundle exec rspec spec --exclude-pattern spec/system/**/*_spec.rb --seed 1234 --format documentation`. Head: `bundle exec rspec spec --exclude-pattern spec/system/**/*_spec.rb --seed 1234 --format documentation`.

Objects per request (all, by run): base 2946.1 / 2945.4, head 2950.1 / 2948.5.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, mail.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | UsersController#new | 3384.5 | 3424.5 | +40.00 | 20.0 |

## Improvements: 0

None.

Not compared: 6 actions (6 no warm value).
