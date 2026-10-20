# frozen_string_literal: true

# A disposable benchmark snapshot, never a deployable build. Only generated
# guard expressions in active Ruby syntax are elided; strings and live input
# predicates are untouched. The compiler still observes the real app loader.
require "json"
require "fileutils"
require "prism"
require_relative "speculation_context"

module SpeculativeBuild
  RECEIVER = /\Aself\.class\.equal\?\(::Lowrail::K\[(\d+)\]\) \|\| ::Lowrail\.ok\?\(\1, self\.class\)\z/
  GLOBAL = /\A::Lowrail::G\[(\d+)\] \|\| ::Lowrail\.check\(\1\)\z/

  def self.elide(source, ids, counts)
    parsed = Prism.parse(source)
    raise "cannot parse lowered source" unless parsed.success?
    nodes = [parsed.value]
    edits = []
    until nodes.empty?
      node = nodes.pop
      if node.type == :or_node && (match = RECEIVER.match(node.location.slice) || GLOBAL.match(node.location.slice)) && ids.include?(Integer(match[1]))
        edits << node.location
        counts[match[1]] = counts.fetch(match[1], 0) + 1
      else
        nodes.concat(node.compact_child_nodes)
      end
    end
    bytes = source.b.dup
    edits.sort_by(&:start_offset).reverse_each do |location|
      bytes[location.start_offset, location.length] = "true".ljust(location.length)
    end
    bytes.force_encoding(source.encoding)
  end

  def self.build(app, target, ids, env, log)
    input = File.join(target, "speculative-input.json")
    FileUtils.mkdir_p(target)
    File.write(input, JSON.generate(app: app, target: target, ids: ids))
    ok = system(env.merge("RUBYOPT" => nil, "LOWRAIL_SPECULATE" => nil, "LOWRAIL_SPECULATE_KEEP" => nil),
      "bundle", "exec", RbConfig.ruby, __FILE__, input, chdir: app, out: log, err: [:child, :out])
    raise "unsafe snapshot compilation failed; inspect #{log}" unless ok
    JSON.parse(File.read(File.join(target, "speculation.json")))
  end

  def self.compile(input)
    raise "unsafe snapshot requires lowrail bench ancestry" unless Lowrail::SpeculationContext.context == "bench"
    warn "[lowrail] *** UNSAFE SOURCE-GUARD ELISION: MEASUREMENT ONLY. NEVER DEPLOY. ***"
    app, target, ids = input.values_at("app", "target", "ids")
    original = JSON.parse(File.read(File.join(app, ".lowrail/manifest.json")))
    plan = JSON.parse(File.read(File.join(app, ".lowrail/units.json")))
    raise "compiler input differs from guarded build; rebuild" unless
      plan.fetch("units") == original.fetch("units") && plan.fetch("rails_env") == original.fetch("rails_env")
    counts = {}
    plan["out"] = target
    plan.fetch("files").each_with_index do |file, index|
      lowered = File.join(target, "source-#{index}.rb")
      File.write(lowered, elide(File.read(file.fetch("lowered")), ids, counts))
      file["lowered"] = lowered
    end
    plan.fetch("templates", {}).each_value do |entry|
      entry["code"] = elide(entry.fetch("code"), ids, counts)
    end
    require_relative "../../gem/lib/lowrail/compiler"
    Lowrail::Compilation.boot(plan)
    # Never write even an intermediate compatible manifest for unsafe code.
    writer = Lowrail.method(:write_json)
    Lowrail.define_singleton_method(:write_json) do |path, data|
      data = data.merge("ruby_description" => "[LOWRAIL UNSAFE] #{data.fetch('ruby_description')}") if path == File.join(target, "manifest.json")
      writer.call(path, data)
    end
    generated = Lowrail::Compiler.compile(plan)
    raise "unsafe compile dropped units" unless generated.fetch("units") == original.fetch("units")
    Lowrail.write_json(File.join(target, "speculation.json"),
      { mode: "unguarded", elided_source_guards: counts, runtime_dispatch_retained: true })
  end
end

SpeculativeBuild.compile(JSON.parse(File.read(ARGV.fetch(0)))) if $PROGRAM_NAME == __FILE__
