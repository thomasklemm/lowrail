# ruby [--zjit] escape_path_check.rb RAILS: which escape path runs (Ruby 4.1 tr! vs escape_binary!).
$LOAD_PATH.unshift(File.join(ARGV[0], "activesupport/lib"))
require "active_support"; require "active_support/json"
E = ActiveSupport::JSON::Encoding
calls = 0
E.singleton_class.prepend(Module.new { define_method(:escape_binary!) { |*a| calls += 1; super(*a) } })
out = [E::JSONGemEncoder, E.json_encoder].uniq.map { |enc| E.json_encoder = enc; ActiveSupport::JSON.encode({ "a" => "<&>\u2028\u2029" }) }
puts "#{RUBY_DESCRIPTION}: TR_ESCAPE_SUPPORTED=#{E::TR_ESCAPE_SUPPORTED} escape_binary! calls=#{calls} out=#{out.uniq.inspect}"
