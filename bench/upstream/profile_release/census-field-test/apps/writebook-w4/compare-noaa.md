# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 16674.9 / 16718.7, head 16664.6 / 16726.9.

A change counts when it exceeds the noise floor: twice the larger run-to-run spread in either report and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | Books::BookmarksController#show | 2852.0 | 2975.5 | +123.50 | 20.0 |

## Improvements: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | Books::SearchesController#create | 97778.15 | 97515.35 | -262.80 | 97.78 |

Not compared: 23 actions (23 no warm value).
