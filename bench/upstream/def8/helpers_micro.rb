# Callgrind or Vernier on one view helper call in a generated app (micro.sh runs it):
#   ruby -rbundler/setup helpers_micro.rb CASE N   (VERN=1: Vernier instead; YJIT=1: keep YJIT on)
ENV["RAILS_ENV"] = "production"
$stdout.reopen(File::NULL)
require "./config/application"
Rails.application.config.yjit = false unless ENV["YJIT"]
require "./config/environment"
abort "yjit on" if RubyVM::YJIT.enabled? && !ENV["YJIT"]
c = PagesController.new
c.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("https://localhost/home", "REMOTE_ADDR" => "127.0.0.1"))
c.response = ActionDispatch::Response.new
v = c.view_context
cases = {
  "noop" => -> { nil },
  "importmap_tags" => -> { v.javascript_importmap_tags },
  "preload_tags" => -> { v.javascript_importmap_module_preload_tags },
  "inline_importmap" => -> { v.javascript_inline_importmap_tag },
  "import_module" => -> { v.javascript_import_module_tag("application") },
  "one_link" => -> { v.tag.link(rel: "modulepreload", href: "/assets/application-bfcdf840.js", nonce: nil, integrity: nil) },
  "stylesheet_app" => -> { v.stylesheet_link_tag(:app, "data-turbo-track": "reload") },
  "stylesheet_named" => -> { v.stylesheet_link_tag("application", "data-turbo-track": "reload") },
  "app_paths" => -> { v.app_stylesheets_paths },
}
name, n = ARGV[0], Integer(ARGV[1])
f = cases.fetch(name)
if ENV["VERN"]
  require "vernier"
  500.times { f.call }
  r = Vernier.profile(mode: :wall, interval: 50) { n.times { f.call } }
  inc = Hash.new(0); slf = Hash.new(0); total = 0
  r.threads.values.each do |t|
    t[:samples].each_with_index do |s, i|
      fr = r.stack(s).frames.map { _1.label.to_s }
      at = fr.rindex { _1.include?("block in <main>") || _1 == "Integer#times" } or next
      fr = fr[0...at]
      next if fr.empty?
      total += t[:weights][i]
      fr.uniq.each { inc[_1] += t[:weights][i] }
      slf[fr.first] += t[:weights][i]
    end
  end
  $stderr.puts inc.sort_by { -_2 }.first(40).map { format("%5.1f%% %s", 100.0 * _2 / total, _1) }
  $stderr.puts "self:", slf.sort_by { -_2 }.first(20).map { format("%5.1f%% %s", 100.0 * _2 / total, _1) }
  exit
end
50.times { f.call }
GC.start; GC.disable
o = GC.stat(:total_allocated_objects)
[f].cycle(n, &:call)
warn "objects=#{(GC.stat(:total_allocated_objects) - o).fdiv(n)}"
