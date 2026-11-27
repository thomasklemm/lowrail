# RK3 third commit, standalone module (e3d53cfd)

Thomas found `Rack::QueryParser::Unescape` (3ca13466) backwards: public `Rack::Utils.unescape` came from a module
under the parser. Rebuilt only the third commit on e26338b40a: fork branch `unescape-cgi-8`, head
`e3d53cfdb2f9689646dc754ea20885bf29169e6a`; the first two commits are unchanged.

New `lib/rack/unescape.rb` (`require 'uri'`, `require 'cgi/escape'`, `Rack::Unescape # :nodoc:` with the private
`unescape`). query_parser.rb replaces its own `require 'uri'`/`'cgi/escape'` with `require_relative 'unescape'`
(it no longer uses either) and has `include Unescape` at the top of the class. utils.rb adds
`require_relative 'unescape'` and keeps `include` + RDoc/YARD blocks + `module_function :unescape` as at 3ca13466.
There is no rack.rb autoload; constants.rb, version.rb and ractorize.rb are other internal files without one.
Precedent for a small shared module in its own file, required by its users: bad_request.rb (723b5384).

Alternatives: 3ca13466 (`QueryParser::Unescape`): the backwards placement. `Rack::Utils::Unescape`: a file that
query_parser.rb loads would define `Rack::Utils` before utils.rb, so `Rack.autoload :Utils` would no longer load
utils.rb after `require "rack/query_parser"`. Rejected.

Checks: `suites.txt` (2.7.3, 3.0.7, 3.1.7, 3.2.9, 3.3.9, 3.4.6, 4.0.9, clean and -rcgi/util: all green, counts as
base); `replay-summary-e3d53cfd.txt` (16 configurations, 204,073 calls each, against e26338b40a; identical
picture to 0046982320/3ca13466: 9,764 message-encoding lines, parameter name, object-address noise, 3.1
error_highlight snippets); `loading-e3d53cfd.txt` (loaded features and order for rack, rack/query_parser,
rack/utils, rack/request, rack/mock_request equal base apart from the added rack/unescape.rb);
`docs-vs-e26338b40a.diff` (whole-lib RDoc 8.1.0 + YARD 0.9.46: call-seq form and the moved private method/module
records only; RDoc 7.2.0 on 2.7.3 lists the entry). RuboCop: 5 offenses as base, none in unescape.rb. Fork CI:
14/14 green.
