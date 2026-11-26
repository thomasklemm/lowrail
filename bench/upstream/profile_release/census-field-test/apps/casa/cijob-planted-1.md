# lowrail-profile compare

Base: `bundle exec rspec spec/requests --seed 1234 --format documentation`. Head: `bundle exec rspec spec/requests --seed 1234 --format documentation`.

Objects per request (all, by run): base 13604.6 / 13605.2, head 13603.3 / 13603.7.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, mail.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | CasaCasesController#index | 10460.2 | 10517.45 | +57.25 | 20.0 |

## Improvements: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | ChecklistItemsController#new | 3496.5 | 3473.0 | -23.50 | 20.0 |

Not compared: 45 actions (45 no warm value).
