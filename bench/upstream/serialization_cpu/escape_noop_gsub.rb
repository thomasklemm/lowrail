# ruby escape_noop_gsub.rb RAILS: a custom encoder whose String has a no-op singleton gsub!, against JSONGemEncoder.
$LOAD_PATH.unshift(File.join(ARGV[0], "activesupport/lib"))
require "active_support"; require "active_support/core_ext/object/with"; require "active_support/json"
E = ActiveSupport::JSON::Encoding
noop = Class.new(E::JSONGemEncoder) { private def stringify(j) = super.tap { |s| def s.gsub!(*) = nil } }
chars = ["<", ">", "&", "\u2028", "\u2029", "a", "é", "’", "\"", "\\"]
srand 1
diff = 0; n = 0
[[true, true], [true, false], [false, true]].each do |html, js|
  2000.times do
    v = { "k" => Array.new(rand(0..12)) { chars.sample }.join }
    a = E.with(json_encoder: noop, escape_html_entities_in_json: html, escape_js_separators_in_json: js) { ActiveSupport::JSON.encode(v) }
    b = E.with(json_encoder: E::JSONGemEncoder, escape_html_entities_in_json: html, escape_js_separators_in_json: js) { ActiveSupport::JSON.encode(v) }
    n += 1; diff += 1 if a != b
  end
end
puts "#{ARGV[0]}: no-op singleton gsub! vs JSONGemEncoder: #{diff} of #{n} differ"
