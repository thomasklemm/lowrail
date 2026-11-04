# frozen_string_literal: true

# Every gem's request CPU and objects from the gem request census receipts, without rank.rb's reach threshold
# (docs/upstream/gem-request-census-2.md).
#   ruby gems_all.rb DIR [gem,gem,...]
# DIR holds the p/ and p2/ labels from docs/upstream/data/gem-request-census/receipts.tar.xz. Columns: apps with any
# sample or object in the gem; mean share of CPU samples over all workloads, interpreter (p2, A/A p2 - p) and YJIT;
# µs per operation (interpreter); objects per operation, interpreter / YJIT. Harness frames and I/O wait are excluded
# as in rank.rb.
require "json"

dir = ARGV[0]
def app_of(c) = c.delete_suffix("-nops").delete_suffix("-mysql")
res = {}
%w[p p2].each do |label|
  %w[interpreter yjit].each do |mode|
    rows = 0
    acc = Hash.new { |h, k| h[k] = { share: 0.0, us: 0.0, obj: 0.0, apps: {} } }
    Dir[File.join(dir, label, "*-#{mode}.json")].each do |path|
      d = JSON.parse(File.read(path))
      d["workloads"].each do |w|
        cpu = w["samples"] - w["wait"] - w["owners"].fetch("harness", 0)
        next if cpu <= 0
        rows += 1
        cpu_us = w["cpu_us_per_op"] * cpu.fdiv(w["samples"] - w["wait"])
        names = (w["owners"].keys | w["objects"]["owners"].keys).select { _1.start_with?("gem:") }
        names.each do |k|
          s = w["owners"].fetch(k, 0).fdiv(cpu)
          a = acc[k.delete_prefix("gem:")]
          a[:share] += s
          a[:us] += s * cpu_us
          a[:obj] += w["objects"]["owners"].fetch(k, 0).fdiv(w["objects_ops"])
          a[:apps][app_of(d["app"])] = true if s > 0 || w["objects"]["owners"].fetch(k, 0) > 0
        end
      end
    end
    acc.each_value { |a| a[:share] /= rows; a[:us] /= rows; a[:obj] /= rows }
    res[[label, mode]] = acc
  end
end
gems = res.values.flat_map(&:keys).uniq
gems &= ARGV[1].split(",") if ARGV[1]
rows = gems.map do |g|
  pi = res[["p2", "interpreter"]][g]; pa = res[["p", "interpreter"]][g]
  py = res[["p2", "yjit"]][g]; pya = res[["p", "yjit"]][g]
  [g, pi[:apps].size, pi[:share] * 100, (pi[:share] - pa[:share]) * 100, py[:share] * 100,
    (py[:share] - pya[:share]) * 100, pi[:us], pi[:obj], py[:obj]]
end
rows.sort_by { -_1[2] }.each do |r|
  puts format("%-28s %3d  %7.3f%% (%+.3f)  %7.3f%% (%+.3f)  %8.1f us  %7.1f / %7.1f obj", *r)
end
