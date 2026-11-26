# lowrail-profile compare

Base: `bundle exec rspec --format documentation --seed 1234`. Head: `bundle exec rspec --format documentation --seed 1234`.

Objects per request (all, by run): base 2182.1 / 2181.9, head 2179.9 / 2206.4.

A change counts when it exceeds the noise floor: twice the base's run-to-run spread across the A/A pair, or head's own if larger, and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request, mail.

**A report, not a gate (exit 0).** What it lists is a place to look: a listed change can be noise, and a small one can be missing (README-profile.md, *Compare*).

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 6 actions (6 no warm value).
