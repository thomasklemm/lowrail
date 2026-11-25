---
id: TA1
repo: rails/rails
kind: fix
area: Action Controller, HTTP token authentication
reviewer: "byroot (merged #58211)"
branch: thomasklemm/token-auth-two-parameter-procedures
head: "a8a0745f1dbb4749bc4bb49deb309fde2b7b290f"
base: main
built_on: "cf0325a832"
depends_on: []
stacked_on:
alternative_of:
impact: "Unreleased since #58211 (156cd688e9, main only): token authentication calls its block with a third argument, so authenticate_with_http_token(&method(:authenticator)) with a two-parameter method raises ArgumentError on every authenticated request (keygen-api, quepid, token_authenticate_me). The fix passes the scheme only to blocks that can take it. Census 11 (docs/upstream/rails-main-census-11.md#ta1)."
rank: 3
risky: false
state: built
pr:
note: "2026-11-25 (census 11): Ownership (2026-11-25): no rails/rails issue or PR on the arity (searched token authentication scheme, wrong number of arguments); #58211's only comment is a thank-you; #59855 (merged 2026-11-18) changed token_and_options, not the call; not in our queue; not fixed on main cf0325a832. built on main cf0325a832. New test fails on main (ArgumentError given 3, expected 2), passes with the fix; http token/basic/digest tests 108 runs 0F. Repro .amp/in/orb-backup/c11/repro/ta1_token_method_arity.rb: 8.1 200, main ArgumentError, fix 200. The CHANGELOG entry of #58211 says 'an optional third argument'; with a lambda it isn't optional. No CHANGELOG entry added (unreleased). Needs: claude-code and thermos passes on this head (probe Symbol#to_proc, keyword-taking methods, method objects with optional third parameter), and Thomas's OK."
passes: []
---

# Don't pass the scheme to two-parameter token authentication lambdas

Since #58211, token authentication calls its block with a third argument, the request's scheme. A method passed as the block is a lambda, so an app that does

```ruby
def authenticate
  authenticate_or_request_with_http_token(&method(:authenticator))
end

def authenticator(token, options)
  # ...
end
```

gets `ArgumentError (wrong number of arguments (given 3, expected 2))` on every request with a token on main, where 8.1 authenticated it. [keygen-api](https://github.com/keygen-sh/keygen-api/blob/master/app/controllers/concerns/authentication.rb) and [quepid](https://github.com/o19s/quepid/blob/main/app/controllers/concerns/api_key_authenticatable.rb) authenticate this way.

This passes the scheme only to blocks that can take it: procs, and lambdas with a third or a rest parameter. Lambdas that take the token and options get those two, as before.
