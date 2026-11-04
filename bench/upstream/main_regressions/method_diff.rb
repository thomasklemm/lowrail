# frozen_string_literal: true

# Per-method cost diff between two Rails pins of the census corpus, with an A/A
# pair on each side (labels BASE, BASE2, HEAD, HEAD2).
#
#   ruby method_diff.rb alloc DIR BASE HEAD [MODE]   # script/census labels (objects per op)
#   ruby method_diff.rb allocfile DIR BASE HEAD [MODE] # the same, per Rails file
#   ruby method_diff.rb cpu   DIR BASE HEAD [MODE]   # script/cpu-census labels (self Ir per op)
#   ruby method_diff.rb cpuincl DIR BASE HEAD [MODE] # the same, inclusive Ir (methods present on both pins)
#
# Allocation sites are per line; each line is mapped to its enclosing method
# (Class#name, or the file for top-level code) with Prism, on each pin's own
# source, so a method keeps its key when its lines move. CPU records already
# carry the method label. A (method, workload) cell moved when all four
# head x base deltas exceed the cell's floor (the larger A/A difference of the
# two pairs) in the same direction, and by at least MIN. Output: one row per
# method with the apps and workloads where it grew, the mean growth over the
# workloads it grew in, and the same for shrinking.
require "json"
require "prism"

kind, dir, base, head, mode = ARGV
mode ||= "interpreter"
MIN = kind.start_with?("alloc") ? 1.0 : 500.0
RAILS_ROOT = File.join(Gem.dir, "bundler/gems")
# BY=name keys methods by their name alone ("#link_to"), so a method that moved
# to another file or module between the pins keeps one key.
BY_NAME = ENV["BY"] == "name"
# BY=class sums a class's or module's methods ("ActiveModel::LazyAttributeSet").
BY_CLASS = ENV["BY"] == "class"
def key(label)
  return label[/[#.][^#.\s]+\z/] || label if BY_NAME
  return label.split(" ", 2).last.sub(/[#.][^#.\s]+\z/, "") if BY_CLASS
  label
end

# Line -> enclosing method name, per file of one Rails checkout.
class MethodMap
  def initialize(root) = (@root, @maps = root, {})

  def name(file, line)
    map = (@maps[file] ||= build(file))
    map.reverse_each { |(first, last, label)| return label if line.between?(first, last) }
    "#{file}:(top)"
  end

  private

  def build(file)
    path = File.join(@root, file)
    return [] unless File.exist?(path)
    out = []
    walk(Prism.parse_file(path).value, [], file, out)
    out.sort_by { |first, last, _| [first, -last] }
  end

  def walk(node, scope, file, out)
    case node
    when Prism::ClassNode, Prism::ModuleNode
      scope += [node.constant_path.slice]
    when Prism::SingletonClassNode
      scope += ["<<self"]
    when Prism::DefNode
      sep = node.receiver || scope.last == "<<self" ? "." : "#"
      owner = scope.reject { _1 == "<<self" }.join("::")
      out << [node.location.start_line, node.location.end_line, "#{file} #{owner}#{sep}#{node.name}"]
    end
    node.compact_child_nodes.each { walk(_1, scope, file, out) }
  end
end

def load_label(kind, dir, label, mode)
  cells = Hash.new { |h, k| h[k] = Hash.new(0.0) }
  Dir["#{dir}/#{label}/*-#{mode}.json"].each do |path|
    run = JSON.parse(File.read(path))
    app = run["app"].sub(/-(mysql|nops)\z/, "")
    if kind.start_with?("alloc")
      map = MethodMap.new(File.join(RAILS_ROOT, run.fetch("rails_dir")))
      run["workloads"].each do |w|
        w["sites"].each do |s|
          next unless s["file"].start_with?("RAILS/")
          file = s["file"].delete_prefix("RAILS/")
          cells[kind == "allocfile" ? file : key(map.name(file, s["line"]))][[app, w["workload"]]] += s["objects_per_op"]
        end
      end
    else
      run["workloads"].each do |w|
        next unless w.fetch("jit_flat", true)
        w["methods"].each do |m|
          next unless m["file"].start_with?("RAILS/")
          cells[key("#{m["file"].delete_prefix("RAILS/")} #{m["method"]}")][[app, w["workload"]]] += m[kind == "cpuincl" ? "incl_ir_per_op" : "self_ir_per_op"]
        end
      end
    end
  end
  cells
end

labels = [base, "#{base}2", head, "#{head}2"].map { load_label(kind, dir, _1, mode) }
workloads = labels.map { |c| c.values.flat_map(&:keys) }.reduce(:&).uniq
rows = labels.flat_map(&:keys).uniq.filter_map do |method|
  b1, b2, h1, h2 = labels.map { _1.fetch(method, {}) }
  grew, shrank = [], []
  workloads.each do |key|
    vb1, vb2, vh1, vh2 = [b1, b2, h1, h2].map { _1.fetch(key, 0.0) }
    next if (kind == "cpuincl" || ENV["BOTH"]) && [vb1, vb2, vh1, vh2].any?(&:zero?)
    floor = [(vb1 - vb2).abs, (vh1 - vh2).abs, MIN].max
    deltas = [vh1 - vb1, vh1 - vb2, vh2 - vb1, vh2 - vb2]
    if deltas.all? { _1 > floor } then grew << [key, deltas.min, (vb1 + vb2) / 2, (vh1 + vh2) / 2]
    elsif deltas.all? { _1 < -floor } then shrank << [key, deltas.max, (vb1 + vb2) / 2, (vh1 + vh2) / 2]
    end
  end
  next if grew.empty? && shrank.empty?
  { method:, grew_apps: grew.map { _1[0][0] }.uniq, grew: grew, shrank_apps: shrank.map { _1[0][0] }.uniq, shrank: shrank }
end

puts "# #{kind} #{mode}: #{base} -> #{head}, #{workloads.size} workloads in all four labels"
puts "# apps_up wl_up mean_up(min delta) | apps_down wl_down mean_down | method | example (base -> head)"
rows.sort_by { [-_1[:grew_apps].size, -_1[:grew].sum { |g| g[1] }] }.each do |r|
  up = r[:grew].empty? ? 0 : r[:grew].sum { _1[1] } / r[:grew].size
  down = r[:shrank].empty? ? 0 : r[:shrank].sum { _1[1] } / r[:shrank].size
  ex = r[:grew].max_by { _1[1] } || r[:shrank].min_by { _1[1] }
  printf("%2d %3d %+10.1f | %2d %3d %+10.1f | %s | %s %s %.1f -> %.1f\n", r[:grew_apps].size, r[:grew].size, up,
    r[:shrank_apps].size, r[:shrank].size, down, r[:method], *ex[0], ex[2], ex[3])
end
