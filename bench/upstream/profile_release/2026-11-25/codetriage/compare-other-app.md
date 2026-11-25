# lowrail-profile compare

Base: `bin/rails test --verbose`. Head: `bundle exec rspec --seed 1234 --format documentation`.

## Insufficient evidence

These reports are not a valid comparison (exit 2):

* base and head differ in identity: {"mode":"command","argv":["bin/rails","test","--verbose"]} and {"mode":"command","argv":["bundle","exec","rspec","--seed","1234","--format","documentation"]}
* base and head differ in ruby: ["ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]"] and ["ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]"]

