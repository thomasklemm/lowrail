# frozen_string_literal: true

# Reconcile the off-only census, retain every allocation/method site, and
# exercise competing rewrite semantics in disposable Ruby processes.
require "json"
require "digest"
require "rbconfig"
require "open3"
require "prism"

input, output = ARGV
abort "usage: default_tier_report.rb CENSUS_DIRECTORY NEW_JSON" unless output && !File.exist?(output)
root = File.expand_path("../..", __dir__)
apps = {"blog" => "real-blog-r4", "fizzy" => "fizzy", "lobsters" => "ruby-bench/benchmarks/lobsters", "campfire" => "campfire-r81"}
refusals = {
  "live_template_arguments" => "Fresh helper arguments/locals/output escape through live sends; freezing, sharing or deleting requires a callee contract.",
  "tag_fragments" => "Live key/value conversions, escaping, options iteration and helper dispatch; fusion removes or changes sends.",
  "safe_buffer" => "Live html_safe?/constructor/escaping dispatch and fresh escaping output; not a dead literal pool.",
  "escaping" => "Live conversion/escaping dispatch; even a literal XML-name Symbol uses to_s, blank? and match?.",
  "route_work" => "Live parameterization/URL methods, scopes and options; no syntax-only elimination identified.",
  "model_work" => "Live values, casts, callbacks, attribute/association dispatch; no syntax-only elimination identified.",
  "app_work" => "Application sends and mutable data remain live; no exact local rewrite established.",
  "other_live_or_unresolved" => "No by-construction rewrite established; gross pool is NOT a proven removable ceiling."
}
classify = ->(path) do
  case path
  when %r{/app/views/} then "live_template_arguments"
  when %r{/tag_helper\.rb} then "tag_fragments"
  when %r{/output_safety\.rb|/action_view/buffers\.rb} then "safe_buffer"
  when %r{/core_ext/erb/util\.rb} then "escaping"
  when %r{/action_dispatch/(?:journey|routing)/|/action_dispatch/http/url\.rb} then "route_work"
  when %r{/active_(?:record|model)/} then "model_work"
  when %r{\AAPP/} then "app_work"
  else "other_live_or_unresolved"
  end
end
raw_pins = {}
read = ->(path) do
  raw_pins[File.basename(path)] = Digest::SHA256.file(path).hexdigest
  JSON.parse(File.read(path))
end
reports = apps.to_h do |app, directory|
  allocations = read.call(File.join(input, "#{app}-allocations.json"))
  profile = read.call(File.join(input, "#{app}-profile.json"))
  untraced = read.call(File.join(input, "#{app}-instructions.json"))
  raise "mode drift" unless [allocations, profile, untraced].all? { _1.fetch("rails") == "8.1.4" && !_1.fetch("yjit") }
  raise "lock drift" unless [allocations, profile, untraced].map { _1.fetch("lock_sha256") }.uniq.size == 1
  raise "harness drift" unless [allocations, profile, untraced].all? do |worker|
    worker.fetch("script_sha256") == Digest::SHA256.file(File.join(__dir__, "default_tier_census.rb")).hexdigest
  end
  totals = (1..4).map do |index|
    path = File.join(input, "#{app}-instructions.cg.#{index}")
    raw_pins[File.basename(path)] = Digest::SHA256.file(path).hexdigest
    Integer(File.read(path).match(/^totals: (\d+)$/).captures.first)
  end
  baseline_ir = [0, 2].map { (totals[_1 + 1] - totals[_1]).fdiv(untraced.fetch("requests")) }
  windows = profile.fetch("profile")
  work_ir = [0, 2].map { (windows[_1 + 1].fetch("work_ir") - windows[_1].fetch("work_ir")).fdiv(profile.fetch("requests")) }
  integrity = windows.all? do |w|
    w.values_at("empty", "truncated", "dropped") == [0, 0, 0] && w["signals"] == w["issued"] && w["lag_max_ir"] <= 3277
  end
  heap_flat = [profile, untraced].all? do |worker|
    worker.fetch("windows").all? do |window|
      window.fetch("pools_before").all? do |pool, before|
        after = window.fetch("pools_after").fetch(pool)
        before.fetch("heap_eden_pages") == after.fetch("heap_eden_pages") &&
          before.fetch("total_allocated_pages") == after.fetch("total_allocated_pages")
      end
    end
  end
  overflow = %w[profile instructions].any? do |mode|
    path = File.join(input, "#{app}-#{mode}.vg")
    raw_pins[File.basename(path)] = Digest::SHA256.file(path).hexdigest
    File.read(path).match?(/brk segment overflow|Cannot map memory to grow brk/)
  end
  details = profile.fetch("details")
  stacks = details.fetch("stacks")
  sample_total = windows.each_with_index.sum { |w, i| (i.odd? ? 1 : -1) * w.fetch("signals") }
  methods = details.fetch("frames").each_with_index.map do |(path, name, line), index|
    self_samples = 0
    inclusive_samples = 0
    stacks.each do |ids, counts|
      count = counts[1] + counts[3] - counts[0] - counts[2]
      self_samples += count if ids.first == index
      inclusive_samples += count if ids.include?(index)
    end
    {path: path, method: name, line: line, self_samples: self_samples, inclusive_samples: inclusive_samples,
      self_pct: 100.0 * self_samples / sample_total, inclusive_pct: 100.0 * inclusive_samples / sample_total,
      approximate_self_ir: work_ir.sum / 2 * self_samples / sample_total,
      disposition: classify.call(path), guard_free_saving_credited: 0}
  end.sort_by { -_1.fetch(:self_samples) }
  gc_samples = windows.each_with_index.sum { |w, i| (i.odd? ? 1 : -1) * w.fetch("gc") }
  raise "sample partition" unless methods.sum { _1.fetch(:self_samples) } + gc_samples == sample_total
  raise "allocation partition" unless allocations.fetch("sites").sum { _1.fetch("objects") } == allocations.fetch("attributed_objects")
  allocations.fetch("sites").each do |site|
    site["disposition"] = classify.call(site.fetch("path"))
    site["guard_free_saving_credited"] = 0
    site["gross_pool_ceiling_objects"] = site.fetch("per_request")
  end
  template_sites = allocations.fetch("sites").select { _1.fetch("path").include?("/app/views/") }
  template_objects = template_sites.sum { _1.fetch("per_request") }
  template_strings = template_sites.select { _1.fetch("class") == "String" }.sum { _1.fetch("per_request") }
  median_objects = allocations.fetch("totals").map { _1.fetch("total_allocated_objects").fdiv(100) }.sort[1]
  app_root = File.join(root, ".corpus", directory)
  source_files = Dir[File.join(app_root, "{app,config,db,test,lib}/**/*")].select do |file|
    File.file?(file) && %w[.rb .erb .jbuilder .yml].include?(File.extname(file))
  end.sort.to_h { [_1.delete_prefix(app_root + "/"), Digest::SHA256.file(_1).hexdigest] }
  [app, {fixture: directory, allocations: allocations, baseline_ir: baseline_ir, sampled_work_ir: work_ir,
    source_sha256: Digest::SHA256.hexdigest(JSON.generate(source_files)),
    fidelity_pct: baseline_ir.zip(work_ir).map { |a, b| 100 * (b / a - 1) },
    diagnostic_controls: {capture_integrity: integrity, heap_flat: heap_flat, brk_overflow: overflow,
      samples: sample_total, gc_samples: gc_samples, raw_windows: windows},
    heap_windows: {profile: profile.fetch("windows"), untraced: untraced.fetch("windows")},
    template_pool: {all_objects: template_objects, all_objects_pct: 100 * template_objects / median_objects,
      strings: template_strings, strings_pct: 100 * template_strings / median_objects,
      self_ir_pct: methods.select { _1.fetch(:path).include?("/app/views/") }.sum { _1.fetch(:self_pct) }},
    methods: methods}]
end

# A syntax-level discovery scan, not a completed pass. Include all app Ruby
# and the five Rails libraries, not only methods that sampling happened to hit.
rails = %w[actionview actionpack activerecord activemodel activesupport].flat_map do |name|
  Dir[File.join(Gem.dir, "gems", "#{name}-8.1.4", "lib", "**", "*.rb")]
end
scan = apps.to_h do |app, directory|
  files = Dir[File.join(root, ".corpus", directory, "app", "**", "*.rb")] + rails
  candidates = []
  errors = []
  files.each do |file|
    parsed = Prism.parse_file(file, version: "4.0.0")
    errors << file if parsed.failure?
    pending = [[parsed.value, nil]]
    until pending.empty?
      node, parent = pending.pop
      if (Prism::AssocSplatNode === node && Prism::HashNode === node.value && Prism::KeywordHashNode === parent) ||
          (Prism::SplatNode === node && Prism::ArrayNode === node.expression && Prism::ArgumentsNode === parent)
        candidates << {file: file.sub(root + "/.corpus/" + directory + "/", "APP/").sub(Gem.dir + "/gems/", "GEM/"),
          line: node.location.start_line, kind: node.type}
      end
      node.compact_child_nodes.each { pending << [_1, node] }
    end
  end
  [app, {files: files.size, parse_errors: errors, literal_call_splats: candidates}]
end
probes = {
  "arithmetic_stays_a_send" => 'eval("def f; 1 + 2; end"); original = f; Integer.class_eval { def +(other); 99; end }; live = f; folded = 3; puts [original, live, folded].inspect',
  "literal_symbol_conversion_stays_live" => 'Symbol.class_eval { def to_s; "data-live"; end }; puts [:class.to_s, "class"].inspect',
  "freezing_helper_arguments_changes_behavior" => 'a = eval(%q{"key"}); b = eval(%q{"key".freeze}); x = (a << "!"); y = begin b << "!"; rescue => e; e.class.name; end; puts [x,y].inspect',
  "combining_appends_changes_dispatch" => 'class Buffer; attr_reader :calls; def initialize; @calls=[]; end; def safe_append=(s); @calls << s; end; end; a=Buffer.new; a.safe_append="left"; a.safe_append="right"; b=Buffer.new; b.safe_append="leftright"; puts [a.calls,b.calls].inspect',
  "fresh_options_cannot_be_shared" => 'def use(h); h[:seen] = h.fetch(:seen,0) + 1; end; a=[use({}),use({})]; h={}; b=[use(h),use(h)]; puts [a,b].inspect'
}
expected = ['[3, 99, 3]', '["data-live", "class"]', '["key!", "FrozenError"]',
  '[["left", "right"], ["leftright"]]', '[[1, 1], [1, 2]]']
probe_results = probes.to_h do |name, source|
  stdout, stderr, status = Open3.capture3(RbConfig.ruby, "--disable-yjit", "-e", source)
  raise "probe failed: #{name}: #{stderr}" unless status.success?
  [name, {source: source, output: stdout.strip}]
end
raise "semantic counterexample drift" unless probe_results.values.map { _1.fetch(:output) } == expected
compiler = {
  "literal_branch" => "def f; if true; 7; else; :never; end; end",
  "dead_array" => "def f; [1,2]; 7; end",
  "unused_destructure" => "def f; a,b=[x,y]; nil; end",
  "frozen_literal" => 'def f; "text".freeze; end',
  "arithmetic" => "def f; 1 + 2; end"
}.transform_values { |source| {source: source, disassembly: RubyVM::InstructionSequence.compile(source).disasm} }
source_pins = %w[bench/experiments/default_tier_census.rb bench/experiments/default_tier_report.rb
  bench/callgrind.c bench/heap_windows.rb bench/worker_placement.rb
  bench/experiments/hotspots.c bench/experiments/hotspots_detail.c
  bench/experiments/hotspots-valgrind.patch fixtures/corpus/lobsters.Gemfile
  fixtures/corpus/lobsters.Gemfile.lock].to_h { [_1, Digest::SHA256.file(File.join(root, _1)).hexdigest] }
File.write(output, JSON.pretty_generate(scope: "off-only discovery; not an optimization price, support claim or impossibility proof",
  base: `git -C #{root} rev-parse HEAD`.strip, refusal_reasons: refusals, apps: reports,
  syntax_scan: scan, semantic_probes: probe_results, compiler: compiler, sources_sha256: source_pins,
  valgrind_sha256: Digest::SHA256.file(File.join(input, "vg/libexec/valgrind/callgrind-amd64-linux")).hexdigest,
  raw_sha256: raw_pins))
reports.each do |app, data|
  puts "#{app}: #{data.fetch(:baseline_ir).join('/')} Ir; template pool #{data.fetch(:template_pool)}"
end
