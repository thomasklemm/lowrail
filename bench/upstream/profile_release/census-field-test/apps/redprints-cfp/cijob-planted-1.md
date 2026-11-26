# lowrail-profile compare

Base: `bundle exec rspec spec --exclude-pattern spec/system/**/*_spec.rb --seed 1234 --format documentation`. Head: `bundle exec rspec spec --exclude-pattern spec/system/**/*_spec.rb --seed 1234 --format documentation`.

Objects per request (all, by run): base 2538.7 / 2540.4, head 2542.9 / 2542.0.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, mail.

## Regressions: 3

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | ProposalsController#index | 3041.0 | 3081.0 | +40.00 | 20.0 |
| request line | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:15` | 0.24 | 1.41 | +1.18 | 1.0 |
| request line | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | 5.18 | 6.35 | +1.18 | 1.0 |

## Improvements: 0

None.

Not compared: 8 actions (8 no warm value).
