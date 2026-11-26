# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 7115.2 / 7109.8, head 7098.7 / 7117.6.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| request action | LeaderboardsController#index | 8260.05 | 8321.25 | +61.20 | 20.0 |

## Improvements: 1

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| job action | SyncRepoMetadataJob#perform | 7145.5 | 5482.65 | -1662.85 | 299.0 |

Not compared: 68 actions (67 no warm value, 1 no warm value in the A/A report).
