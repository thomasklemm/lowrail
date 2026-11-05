# frozen_string_literal: true

require "json"
require "open3"

module StackMapReport
  def self.layer(path, label = "")
    text = "#{path} #{label}"
    return "driver C" if path == "<cfunc>" && label.match?(/\A(?:SQLite3|PG)::/)
    return "JSON" if label.match?(/\AJSON(?:::|\.)/)
    return nil if path == "<cfunc>" || path.start_with?("<internal:")
    return "Puma" if path.include?("/puma/")
    return "Rack" if path.match?(%r{/rack(?:/|-)|/rack-session-})
    return "routing" if path.include?("action_dispatch/journey") || path.include?("action_dispatch/routing")
    return "callbacks" if path.include?("active_support/callbacks")
    return "controller" if path.match?(%r{/action_controller/|/abstract_controller/|/app/controllers/})
    return "Active Record Ruby" if path.match?(%r{/active_record/|/active_model/|/arel/})
    return "Action View / templates" if path.match?(%r{/action_view/|/app/views/|/views/|\.(?:erb|herb)\z})
    return "JSON" if path.match?(%r{/(?:json|jbuilder)(?:/|-)})
    return "AS instrumentation" if path.include?("active_support/notifications") || path.include?("active_support/subscriber")
    return "AS execution state" if path.include?("isolated_execution_state")
    return "logging" if text.match?(%r{/logger(?:/|\.|-)|/active_support/(?:tagged_logging|logger|log_subscriber|event_reporter)})
    return "Active Support other" if path.include?("/active_support/")
    return "middleware / dispatch" if path.include?("/action_dispatch/")
    return "app models" if path.include?("/app/models/")
    return "harness" if path.include?("/bench/upstream/") || path.end_with?("/benchmark.rb")
    return "gem: #{$1}" if path =~ %r{/gems/([^/]+?)-\d[^/]*/}
    return "app / other" if path.include?("/ruby-bench/") || path.include?("/.corpus/")
    "Ruby stdlib / other"
  end

  def self.ruby_stacks(path)
    data = JSON.parse(File.read(path))
    exclusive, inclusive, leaves = [Hash.new(0), Hash.new(0), Hash.new(0)]
    data.fetch("stacks").each do |stack, count|
      frames = stack.map { |id, _line| data.fetch("frames").fetch(id) }
      layers = frames.filter_map { |file, label, _| layer(file.to_s, label.to_s) }
      owner = layers.first || "unattributed"
      exclusive[owner] += count
      layers.uniq.each { inclusive[_1] += count }
      leaf = frames.find { |file, label, _| layer(file.to_s, label.to_s) }
      leaves[leaf.join(":")] += count if leaf
    end
    gc = data.fetch("window").fetch("gc")
    exclusive["GC"] = gc
    inclusive["GC"] = gc
    signals = data.fetch("window").fetch("signals")
    raise "stack samples do not reconcile" unless exclusive.values.sum + data["window"]["empty"] + data["window"]["dropped"] == signals
    { samples: signals, ir: data["window"]["work_ir"], exclusive: exclusive.sort_by { -_2 }.to_h,
      inclusive: inclusive.sort_by { -_2 }.to_h, leaves: leaves.sort_by { -_2 }.first(80).to_h }
  end

  def self.perf_owner(stack)
    return "kernel / syscalls" if stack.first&.last == "[kernel.kallsyms]"
    return "GC" if stack.any? { |sym, _| sym.match?(/\Agc_(?:sweep|marks|mark|start|enter)|\Agc_(?:rest|verify)|\Arb_gc_(?:start|mark)|\A(?:mark_current|mark_locations|objspace_malloc_increase)/) }
    return "YJIT compiler" if stack.any? { |sym, _| sym.match?(/rb_yjit_(?:compile|branch_stub_hit)|yjit::(?:codegen|asm::)|yjit::core::.*compile/) }
    stack.each do |sym, dso|
      return "VM / native unresolved" if sym.match?(/\A(?:rb_vm_exec|vm_exec_core)\b/)
      return "driver C" if dso.match?(/sqlite3|libpq|\/pg_ext\.so/)
      return "JSON" if dso.match?(%r{/json/.*\.so})
      next unless sym.start_with?("[JIT]")
      return "YJIT runtime / exits unresolved" unless sym.include?("@")
      return layer(sym.split("@", 2).last.sub(/:\d+\z/, ""), sym) || "VM / native unresolved"
    end
    "VM / native unresolved"
  end

  def self.perf(path)
    exclusive, inclusive, leaves, dsos = Array.new(4) { Hash.new(0) }
    lost = 0
    stack = []
    consume = -> {
      unless stack.empty?
        owner = perf_owner(stack)
        exclusive[owner] += 1
        layers = stack.filter_map do |symbol, _|
          next unless symbol.start_with?("[JIT]") && symbol.include?("@")
          layer(symbol.split("@", 2).last.sub(/:\d+\z/, ""), symbol)
        end
        (layers << owner).uniq.each { inclusive[_1] += 1 }
        leaves[stack.first.join(" ")] += 1
        dsos[stack.first.last] += 1
      end
      stack = []
    }
    Open3.popen2("sudo", "perf", "script", "-f", "--no-inline", "--show-lost-events", "-i", path,
      "--max-stack", "128", "-F", "pid,tid,time,event,ip,sym,dso") do |input, output, worker|
      input.close
      output.each_line do |line|
        if line =~ /PERF_RECORD_LOST lost (\d+)/
          consume.call
          lost += Integer($1)
        elsif line.strip.empty?
          consume.call
        elsif line =~ /^\s+[\da-f]+ (.+) \((.+)\)\s*$/
          stack << [$1, $2] unless $2 == "inlined"
        end
      end
      consume.call
      raise "perf script failed" unless worker.value.success?
    end
    { samples: exclusive.values.sum, lost_samples: lost, exclusive: exclusive.sort_by { -_2 }.to_h,
      inclusive_lower_bound: inclusive.sort_by { -_2 }.to_h,
      leaves: leaves.sort_by { -_2 }.first(100).to_h, dsos: dsos.sort_by { -_2 }.to_h }
  end
end

if $PROGRAM_NAME == __FILE__
  kind, path = ARGV
  puts JSON.pretty_generate(kind == "perf" ? StackMapReport.perf(path) : StackMapReport.ruby_stacks(path))
end
