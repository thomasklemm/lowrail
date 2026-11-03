# frozen_string_literal: true

# Boot profiles from probe.rb (cpu kind: stackprof wall samples, raw stacks;
# objects kind: every allocation) by phase, owner and Rails frame.
#   ruby bench/upstream/boot/analyze.rb phases JSON...      per-file phase x stage table
#   ruby bench/upstream/boot/analyze.rb owners JSON...      self time by owner (Rails component, gem, app, VM)
#   ruby bench/upstream/boot/analyze.rb frames JSON...      Rails frames ranked across files (apps)
#   ruby bench/upstream/boot/analyze.rb sites JSON...       allocation sites (objects kind), top N
# BOOT_TOP=N sets the length of ranked lists (default 40).
require "json"

module BootAnalyze
  # Innermost marker wins: a sample belongs to the deepest phase frame on its stack.
  PHASES = [
    [:template_compile, ->(n) { n == "ActionView::Template#compile!" }],
    [:i18n_load, ->(n) { n == "I18n::Backend::Base#load_translations" || n == "I18n::Backend::Simple::Implementation#init_translations" }],
    [:schema_load, ->(n) { n.end_with?("#load_schema!") || n == "ActiveRecord::ModelSchema::ClassMethods#load_schema" }],
    [:route_compile, ->(n) { n == "ActionDispatch::Routing::RouteSet#eager_load!" || n == "ActionDispatch::Journey::Router#eager_load!" }],
    [:routes_draw, ->(n) { n == "ActionDispatch::Routing::RouteSet#draw" || n == "Rails::Application::RoutesReloader#load_paths" }],
    [:zeitwerk_eager_load, ->(n) { n == "Zeitwerk::Loader.eager_load_all" || n == "Zeitwerk::Loader::EagerLoad#eager_load" }],
    [:framework_eager_load, ->(n) { n.end_with?(".eager_load!") }],
    [:config_initializers, ->(n) { n == "Rails::Engine#load_config_initializer" }],
    [:other_initializers, ->(n) { n == "Rails::Initializable::Initializer#run" }],
    [:bundler_require, ->(n) { n == "Bundler.require" }],
    [:bundler_setup, ->(n) { n == "Bundler.setup" }],
  ].freeze
  PHASE_NAMES = PHASES.map(&:first) + %i[gc other]
  REQUIRE = /\A(Kernel[#.](require|require_relative|load)|Bootsnap::.*|RubyVM::InstructionSequence\.(load_from_binary|compile.*)|Kernel#eval|BasicObject#instance_eval|Module#(class|module)_eval)\z/

  module_function

  def load(path)
    r = JSON.parse(File.read(path))
    p = r.fetch("profile")
    frames = p["frames"].to_h { |id, (name, file, line)| [id.to_i, [name, file, line]] }
    [r, p, frames]
  end

  def phase_of(stack, frames)
    return :gc if frames[stack.first]&.first == "(garbage collection)"
    stack.reverse_each do |id|
      name = frames[id]&.first or next
      PHASES.each { |phase, test| return phase if test.(name) }
    end
    :other
  end

  def stage_of(stack, frames) = stack.any? { frames[_1]&.first == "BootProbe.first_request" } ? :request : :boot

  def rails_component(file)
    file[%r{/(?:bundler/gems/rails-\h+|gems/rails-[\d.]+)/([a-z]+)/}, 1] ||
      file[%r{/gems/(activesupport|activemodel|activerecord|activejob|activestorage|actionpack|actionview|actionmailer|actioncable|actionmailbox|actiontext|railties)-[\d.]+\w*/}, 1]
  end

  def owner(file, app_root)
    return "?" unless file
    if (c = rails_component(file)) then "rails:#{c}"
    elsif (g = file[%r{/gems/([^/]+?)-\d[^/]*/}, 1] || file[%r{/bundler/gems/([^/]+?)-\h{7,}/}, 1]) then "gem:#{g}"
    elsif app_root && file.start_with?(app_root) then "app"
    elsif file.include?("/lib/ruby/4.") || file.include?("/lib/ruby/3.") then "stdlib"
    elsif file.include?("bench/upstream") then "probe"
    else "other"
    end
  end

  # Self time goes to the leaf frame; a C function's self time goes to its
  # nearest Ruby caller's owner, except loading code (require, ISeq load,
  # eval), which is its own owner.
  def leaf_owner(stack, frames, app_root)
    leaf = frames[stack.last]
    return "gc" if leaf&.first&.start_with?("(")
    return "vm:require+compile" if leaf && leaf[0].match?(REQUIRE)
    stack.reverse_each do |id|
      name, file, = frames[id]
      next if file.nil? || file == "<cfunc>" || file.empty?
      return owner(file, app_root)
    end
    "?"
  end

  def app_root(r) = r["gems"] && r["gems"].values.grep(%r{/\.corpus/}).first&.then { _1[%r{\A.*?/\.corpus/[^/]+}] }

  def weight(p) = p["mode"] == "object" ? 1.0 : p["interval"] / 1000.0

  # Runs of one app are pooled; values are means per run.
  def by_app(paths)
    paths.group_by { File.basename(_1)[/\A[a-z-]+?(?=-(cpu|objects))/] }.map do |_, group|
      loaded = group.map { load(_1) }
      [loaded.first[0]["app"], loaded, group.size]
    end
  end

  def phases(paths)
    by_app(paths).each do |app, runs, n|
      t = Hash.new(0.0)
      unit = nil
      runs.each do |r, p, frames|
        w = weight(p) / n
        unit = p["mode"] == "object" ? "objects" : "ms"
        p["stacks"].each { |stack, c| t[[stage_of(stack, frames), phase_of(stack, frames)]] += c * w }
      end
      total = t.values.sum
      puts "## #{app} (#{n} runs): #{total.round} #{unit} sampled per run"
      %i[boot request].each do |stage|
        rows = PHASE_NAMES.map { [_1, t[[stage, _1]]] }.select { _2 > 0 }
        puts "  #{stage}: " + rows.map { |ph, v| "#{ph} #{v.round} (#{(100 * v / total).round(1)}%)" }.join(", ")
      end
    end
  end

  def owners(paths)
    top = Integer(ENV.fetch("BOOT_TOP", "40"))
    by_app(paths).each do |app, runs, n|
      t = Hash.new(0.0)
      runs.each do |r, p, frames|
        w = weight(p) / n
        root = app_root(r)
        p["stacks"].each { |stack, c| t[leaf_owner(stack, frames, root)] += c * w }
      end
      total = t.values.sum
      rails = t.select { |k, _| k.start_with?("rails:") }.values.sum
      puts "## #{app} (#{n} runs): total #{total.round}, Rails #{rails.round} (#{(100 * rails / total).round(1)}%)"
      t.sort_by { -_2 }.first(top).each { |k, v| puts format("  %-34s %8.0f %5.1f%%", k, v, 100 * v / total) }
    end
  end

  # Rails frames: self and total (inclusive, once per sample) per app, ranked by apps reached and mean share.
  def frames(paths)
    top = Integer(ENV.fetch("BOOT_TOP", "40"))
    per = {}
    by_app(paths).each do |app, runs, n|
      total = 0.0
      selfs = Hash.new(0.0)
      totals = Hash.new(0.0)
      runs.each do |_r, p, frames|
        w = weight(p) / n
        p["stacks"].each do |stack, c|
          total += c * w
          # Self time at the nearest Ruby frame, naming the C function it called.
          leaf = frames[stack.last]
          ruby = stack.reverse_each.map { frames[_1] }.find { |_, file, _| file && file != "<cfunc>" && !file.empty? }
          if ruby && rails_component(ruby[1])
            selfs[leaf && leaf[1] == "<cfunc>" ? "#{ruby[0]} > #{leaf[0]}" : ruby[0]] += c * w
          end
          stack.uniq.each do |id|
            name, file, = frames[id]
            totals[name] += c * w if file && rails_component(file)
          end
        end
      end
      per[app] = { total:, selfs:, totals: }
    end
    %i[totals selfs].each do |kind|
      names = per.values.flat_map { _1[kind].keys }.uniq
      rows = names.map do |name|
        shares = per.transform_values { 100 * _1[kind][name] / _1[:total] }
        [name, shares.count { _2 >= 0.5 }, shares.values.sum / per.size, shares]
      end
      puts "## Rails frames by #{kind == :totals ? "total (inclusive)" : "self"} time: apps ≥ 0.5%, mean %, per app"
      rows.sort_by { [-_2, -_3] }.first(top).each do |name, reach, mean, shares|
        puts format("  %-70s %d %5.1f  %s", name[0, 70], reach, mean, shares.map { |a, s| "#{a} #{s.round(1)}" }.join(", "))
      end
    end
  end

  def sites(paths)
    top = Integer(ENV.fetch("BOOT_TOP", "40"))
    paths.each do |path|
      r, p, frames = load(path)
      root = app_root(r)
      t = Hash.new(0)
      own = Hash.new(0)
      p["stacks"].each do |stack, n|
        # The allocating Ruby line: the deepest frame with a file (C functions report their caller's line).
        id = stack.reverse.find { f = frames[_1]; f && f[1] && f[1] != "<cfunc>" && !f[1].empty? }
        name, file, line = frames[id] || ["?", "?", 0]
        leaf = frames[stack.last]&.first
        t[[owner(file, root), "#{file.to_s.sub(%r{.*/(gems|bundler/gems)/}, "")}:#{line} #{name}", leaf]] += n
        own[owner(file, root)] += n
      end
      total = t.values.sum
      puts "## #{r["app"]}: #{total} allocations sampled; by owner: " +
        own.sort_by { -_2 }.first(12).map { |k, v| "#{k} #{(100.0 * v / total).round(1)}%" }.join(", ")
      t.sort_by { -_2 }.first(top).each { |(o, site, leaf), n| puts format("  %8d %5.2f%% %-14s %s [%s]", n, 100.0 * n / total, o, site[0, 110], leaf) }
    end
  end
end

BootAnalyze.public_send(ARGV.shift, ARGV) if $PROGRAM_NAME == __FILE__
