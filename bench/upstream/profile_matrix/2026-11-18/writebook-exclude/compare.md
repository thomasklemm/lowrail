# Lowrail profile compare

Base: `bin/rails test -v --exclude /test_unpublishing_a_book_revokes_the_disk_URL/`. Head: `bin/rails test -v --exclude /test_unpublishing_a_book_revokes_the_disk_URL/`.

Objects per request (all, by run): base 13791.4 / 13791.0, head 13791.8 / 13790.9.

A change counts when it exceeds the noise floor: for a line the base's run-to-run spread across the A/A pair, or head's own if larger, and at least 1.0 objects per request (warm); for an action twice that spread, 0.1% of its objects and at least 20.0. Compared: request, job.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 22 actions (22 no warm value).
