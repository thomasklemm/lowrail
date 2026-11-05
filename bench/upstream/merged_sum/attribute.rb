# frozen_string_literal: true

# Attributes the census allocation difference between Rails main ("with") and
# main with our merged perf PRs reverted ("without") to individual PRs, for
# docs/upstream/merged-sum.md.
#   ruby attribute.rb CENSUS_OUT MAIN_TREE REVERTED_TREE PRS_TSV
# PRS_TSV: "NUMBER<TAB>MERGE_SHA" per reverted PR. LABELS=with,with2,without,without2
# names the census labels (default sum-with,sum-with2,sum-without,sum-without2). Per allocation site
# (RAILS/file:line), the change is the mean over each A/A pair (with, with2;
# without, without2), summed over all workloads of a mode. A site is assigned
# by `git blame` of its line: in the reverted tree a line from a revert commit
# belongs to that PR; on main a line from a commit inside the PR's branch does.
# Sites whose line neither tree blames on a PR fall back to the file, when
# exactly one reverted PR touched it; the rest stay unattributed.
require "json"
require "open3"

out, main_tree, rev_tree, prs_tsv = ARGV
abort "usage: attribute.rb CENSUS_OUT MAIN_TREE REVERTED_TREE PRS_TSV" unless prs_tsv

def git(dir, *args) = Open3.capture2("git", "-C", dir, *args).first

prs = File.readlines(prs_tsv, chomp: true).map { _1.split("\t").first(2) }
commit_pr = {}
file_prs = Hash.new { |h, k| h[k] = [] }
prs.each do |num, merge|
  git(main_tree, "rev-list", "#{merge}^1..#{merge}^2").split.each { commit_pr[_1] = num }
  commit_pr[merge] = num
  git(main_tree, "diff", "--name-only", "#{merge}^1", merge).split.each { file_prs[_1] << num }
end
# Revert commits in the reverted tree: their message names the merge commit.
base = git(main_tree, "rev-parse", "HEAD").strip
git(rev_tree, "log", "--format=%H %B%x00", "#{base}..HEAD").split("\0").each do |entry|
  sha = entry.strip[/\A\h{40}/] or next
  merge = entry[/This reverts commit (\h{40})/, 1] or next
  num = prs.find { |_, m| merge.start_with?(git(main_tree, "rev-parse", m).strip) }&.first
  commit_pr[sha] = num if num
end

# PRs that share a lib file form one group (union-find), so an allocation a PR
# moves from one line to another nets out inside its group.
parent = {}
find = ->(x) { parent[x] == x ? x : (parent[x] = find.(parent[x])) }
prs.each { |num, _| parent[num] = num }
file_prs.each_value { |nums| nums.uniq.each_cons(2) { |a, b| parent[find.(a)] = find.(b) } }
groups = prs.map(&:first).group_by { find.(_1) }.values.map(&:sort)
group_of = {}
file_prs.each { |file, nums| group_of[file] = groups.find { _1.include?(nums.first) }.join("+") }
blame_cache = {}
blame = lambda do |tree, file, line|
  blame_cache[[tree, file]] ||= begin
    lines = {}
    cur = nil
    git(tree, "blame", "--porcelain", "--", file).each_line do |l|
      if (m = l.match(/\A(\h{40}) \d+ (\d+)/))
        cur = m[1]
        lines[m[2].to_i] = cur
      end
    end
    lines
  end
  blame_cache[[tree, file]][line]
end

sites = ->(label, file) do
  path = File.join(out, label, file)
  JSON.parse(File.read(path))["workloads"].each_with_object(Hash.new(0.0)) do |w, acc|
    w["sites"].each { |s| acc[[s["file"], s["line"]]] += s["objects_per_op"] if s["file"].start_with?("RAILS/") }
  end
end

labels = ENV.fetch("LABELS", "sum-with,sum-with2,sum-without,sum-without2").split(",")
result = {}
%w[interpreter yjit].each do |mode|
  files = Dir[File.join(out, labels[0], "*-#{mode}.json")].map { File.basename(_1) }
  per_pr = Hash.new(0.0)
  per_app_total = Hash.new(0.0)
  per_app_pr = Hash.new { |h, k| h[k] = Hash.new(0.0) }
  files.each do |f|
    app = f.delete_suffix("-#{mode}.json")
    next unless labels.all? { File.exist?(File.join(out, _1, f)) }
    w1, w2, o1, o2 = labels.map { sites.(_1, f) }
    keys = (w1.keys | w2.keys | o1.keys | o2.keys)
    keys.each do |k|
      d = (w1[k] + w2[k]) / 2 - (o1[k] + o2[k]) / 2
      next if d.abs < 0.5
      file = k[0].delete_prefix("RAILS/")
      pr = group_of[file] || "other: #{file}"
      if ENV["SPLIT"] && pr.include?("+")
        b = commit_pr[blame.(rev_tree, file, k[1])] || commit_pr[blame.(main_tree, file, k[1])]
        pr = "#{pr} / #{b || "?"}"
      end
      per_pr[pr] += d
      per_app_total[app] += d
      per_app_pr[app][pr] += d
    end
  end
  result[mode] = { per_pr: per_pr.sort_by { _2 }, per_app: per_app_total,
                  per_app_pr: per_app_pr.transform_values { |h| h.sort_by { _2 }.first(6).to_h { |k, v| [k, v.round(1)] } } }
end
puts JSON.pretty_generate(result)
