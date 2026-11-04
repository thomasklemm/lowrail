# Ruby 4.1's default json is 3.1.0, which rejects unknown options. Active
# Support 7.0-8.0.5.2 passes quirks_mode:, 8.1.0-8.1.3.1 passes options
# positionally to JSON.parse. Run with -I<activesupport-VERSION>/lib and no
# json gem in the bundle.
require "active_support"
require "active_support/json"
r = []
begin; r << "encode=#{ActiveSupport::JSON.encode({a: 1}).inspect}"; rescue => e; r << "encode #{e.class}: #{e.message}"; end
begin; r << "decode=#{ActiveSupport::JSON.decode('{"a":1}').inspect}"; rescue => e; r << "decode #{e.class}: #{e.message}"; end
puts "AS #{ActiveSupport.version} json #{JSON::VERSION}: #{r.join('; ')}"
