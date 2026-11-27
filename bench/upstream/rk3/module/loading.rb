# ruby -I RACK/lib loading.rb ENTRY: what an entry require loads, and whether unescape works from it.
before = $LOADED_FEATURES.dup
require ARGV[0]
loaded = ($LOADED_FEATURES - before).map { |f| f[%r{(rack/.*|[^/]+)\z}] }.sort
p entry: ARGV[0], loaded: loaded
p utils_autoload: Rack.autoload?(:Utils), qp_autoload: Rack.autoload?(:QueryParser)
p qp: (Rack::QueryParser.make_default(32).parse_query("a=%41+b") rescue $!), utils: (Rack::Utils.unescape("%41+b") rescue $!)
p loaded_after_use: (($LOADED_FEATURES - before).map { |f| f[%r{(rack/.*|[^/]+)\z}] }.sort - loaded)
