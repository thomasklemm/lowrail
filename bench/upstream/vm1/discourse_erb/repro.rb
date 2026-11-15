# Renders `<%= str %>` through ActionController/ActionView (ERB handler, Erubi) for strings with invalid
# UTF-8, binary high bytes and valid non-ASCII, with or without Discourse's lib/freedom_patches/erb_util.rb
# loaded after Rails as its initializer does. Prints the body bytes or the exception for each case.
#   ruby repro.rb RAILS_TREE [PATCH_FILE...]
tree, *patches = ARGV
%w[activesupport actionview activemodel actionpack].each { $LOAD_PATH.unshift File.join(tree, _1, "lib") }
require "tmpdir"
require "action_controller"
require "action_view"
patches.each { load _1 }

dir = Dir.mktmpdir
FileUtils.mkdir_p("#{dir}/demo")
File.write("#{dir}/demo/ascii.html.erb", "<p><%= str %></p>")
File.write("#{dir}/demo/utf8.html.erb", "<p>Café <%= str %></p>")
File.write("#{dir}/demo/helper.html.erb", "<p>Café <%= h(str) %></p>")

class DemoController < ActionController::Base; end
DemoController.view_paths = [dir]

Wrapper = Struct.new(:text) { def to_s = text }
inputs = {
  "invalid UTF-8" => "caf\xE9 <b>".dup.force_encoding("UTF-8"),
  "invalid UTF-8 via to_s" => Wrapper.new("caf\xE9 <b>".dup.force_encoding("UTF-8")),
  "binary, UTF-8 bytes" => "caf\xC3\xA9 <b>".b,
  "binary, invalid bytes" => "caf\xE9 <b>".b,
  "valid non-ASCII" => "café <b>",
}

def show(s) = "#{s.dump} (#{s.encoding}, #{s.valid_encoding? ? "valid" : "invalid"})"

inputs.each do |name, str|
  %w[ascii utf8 helper].each do |template|
    result = begin
      show(DemoController.render(template: "demo/#{template}", locals: { str: str }))
    rescue => e
      "#{e.class}: #{e.message.lines.first.chomp}"
    end
    puts "#{name} | #{template} | #{result}"
  end
  direct = begin
    show(ERB::Util.html_escape(str))
  rescue => e
    "#{e.class}: #{e.message.lines.first.chomp}"
  end
  puts "#{name} | ERB::Util.html_escape | #{direct}"
end

view = ActionView::Base.empty
invalid = inputs.fetch("invalid UTF-8")
{
  "tag.p content" => -> { view.tag.p(invalid) },
  "tag.p title:" => -> { view.tag.p("x", title: invalid) },
  "html_escape_once" => -> { ERB::Util.html_escape_once(invalid) },
}.each do |name, call|
  result = begin
    show(call.call)
  rescue => e
    "#{e.class}: #{e.message.lines.first.chomp}"
  end
  puts "invalid UTF-8 | #{name} | #{result}"
end
