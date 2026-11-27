# ruby extract_asserts.rb TEST_FILE > asserts.rb: one entry per statement of the two decode tests, with its line.
require "prism"
tree = Prism.parse_file(ARGV[0]).value
src = File.read(ARGV[0])
out = []
tree.breadth_first_search { |n| n.is_a?(Prism::DefNode) && %i[test_decode_www_form_component test_decode_uri_component].include?(n.name) && (out << n; false) }
tree.accept(Class.new(Prism::Visitor) { define_method(:visit_def_node) { |n| (out << n) if %i[test_decode_www_form_component test_decode_uri_component].include?(n.name) } }.new) if out.empty?
puts "ASSERTS = ["
out.each { |d| d.body.body.each { |s| puts "  [#{d.name.to_s.sub("test_decode_", "").inspect}, #{s.location.start_line}, #{s.slice.inspect}]," } }
puts "]"
