# lowrail-profile compare

Base: `bin/rails test -v`. Head: `bin/rails test -v`.

Objects per request (all, by run): base 7115.2 / 7109.8, head 6826.2 / 7107.4.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, job, mail.

## Regressions: 2

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| job action | ReconcileActiveRepositoriesJob#perform | 864.15 | 991.15 | +127.00 | 65.4 |
| request action | LeaderboardsController#index | 8260.05 | 8283.0 | +22.95 | 20.0 |

## Improvements: 2

| Kind | Line or action | Base | Head | Δ | Noise floor |
| --- | --- | ---: | ---: | ---: | ---: |
| job action | SyncRepoMetadataJob#perform | 7145.5 | 5360.35 | -1785.15 | 398.6 |
| job line | `GEM/addressable/lib/addressable/uri.rb:424` | 1.19 | 0.0 | -1.19 | 1.0 |

Not compared: 70 actions (69 no warm value, 1 no warm value in the A/A report).
