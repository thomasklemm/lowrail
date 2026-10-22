# frozen_string_literal: true

# Operation-level diagnostic, not the fixed-heap request screen or a speed claim.
require "json"
require "digest"
require_relative "../jit_stability"

gem_name, base, source, output, command = ARGV
base, source, output = [base, source, output].map { File.expand_path(_1) }
raise "new output required" if File.exist?(output)
JitStability.assert_mode!
if gem_name == "useragent"
  $LOAD_PATH.unshift(File.join(base, "lib"))
  require "user_agent"
  load source
  agents = [
    "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36",
    "Googlebot/2.1 (+http://www.google.com/bot.html)"
  ]
  versions = ["", "1", "1.2.34", "12.7rc3", "1.2.3-beta", "preview", "  ", "1.2.3.4.5.6.7"]
  snapshot = agents.map { UserAgent.parse(_1).to_h } + versions.map do |string|
    version = UserAgent::Version.new(string)
    copy = version.to_a
    original = copy.dup
    copy.clear
    raise "sequence ownership changed" unless version.to_a == original
    [version.to_s, version.to_a, version.nil?, version <=> "2.3"]
  end
  operations = {
    "firefox" => -> { UserAgent.parse(agents[0]).to_h },
    "numeric_version" => -> { UserAgent::Version.new("140.2.31") },
    "nonnumeric_control" => -> { UserAgent::Version.new("preview") }
  }
elsif gem_name == "importmap"
  require "active_support/all"
  require "action_view"
  module Importmap; end
  load source
  request_class = Struct.new(:nonce, :calls) do
    def content_security_policy_nonce
      self.calls += 1
      nonce
    end
  end
  package_class = Struct.new(:integrity)
  map_class = Struct.new(:packages) do
    def preloaded_module_packages(**)
      packages
    end
  end
  view = ActionView::Base.empty
  view.extend(Importmap::ImportmapTagsHelper)
  request = request_class.new(nil, 0)
  view.define_singleton_method(:request) { request }
  snapshot = [nil, "nonce<&\"", "second-nonce"].flat_map do |nonce|
    request.nonce = nonce
    [[], ["/alpha.js"], ["/a?x=1&y=<2>", "/a?x=1&y=<2>"], ["/already&amp;.js".html_safe], ["/é.js", "https://cdn.example/x.js"]].flat_map do |paths|
      packages = paths.to_h { [_1, package_class.new("sha384-<&\"")] }
      [-> { view.javascript_module_preload_tag(*paths) },
        -> { view.javascript_importmap_module_preload_tags(map_class.new(packages)) }].map do |call|
        request.calls = 0
        value = call.call
        [value, value.class.name, value.encoding.name, value.html_safe?, value.frozen?, request.calls]
      end
    end
  end
  request.nonce = "benchmark-nonce"
  paths = Array.new(8) { |i| "/assets/module-#{i}.js" }
  map = map_class.new(paths.each_with_index.to_h { |path, i| [path, package_class.new(i.odd? ? "sha384-integrity" : nil)] })
  operations = {
    "packages_8" => -> { view.javascript_importmap_module_preload_tags(map) },
    "paths_8" => -> { view.javascript_module_preload_tag(*paths) },
    "empty_control" => -> { view.javascript_module_preload_tag }
  }
else
  raise "unknown gem"
end

result = {ruby: RUBY_DESCRIPTION, gem: gem_name, source_sha256: Digest::SHA256.file(source).hexdigest,
  mode: JitStability.actual, snapshot: snapshot}
unless command == "snapshot"
  result[:cases] = operations.to_h do |name, operation|
    loop_work = ->(n, _) { n.times { operation.call } }
    10_000.times { operation.call }
    warm = JitStability.enabled? ? JitStability.warm(rehearsal_requests: 100, &loop_work) : nil
    n = gem_name == "importmap" ? 2_000 : 10_000
    GC.start
    allocations = GC.stat(:total_allocated_objects)
    loop_work.call(n, nil)
    allocated = (GC.stat(:total_allocated_objects) - allocations).fdiv(n)
    GC.start
    before = JitStability.snapshot if JitStability.enabled?
    start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    loop_work.call(n, nil)
    cpu = (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - start) * 1e6 / n
    after = JitStability.snapshot if JitStability.enabled?
    [name, {allocations: allocated, cpu_us: cpu, jit_warmup: warm, jit_before: before, jit_after: after}]
  end
end
File.write(output, JSON.pretty_generate(result) + "\n")
puts JSON.generate(result.except(:snapshot, :cases).merge(cases: result[:cases]&.transform_values { _1.slice(:allocations, :cpu_us) }))
