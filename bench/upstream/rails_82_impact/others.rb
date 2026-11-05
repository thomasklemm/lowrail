# frozen_string_literal: true

# Allocation attribution for everyone else's share in
# docs/upstream/rails-82-impact.md, for the record only: the change from
# 8-1-stable ("old") to main with our merged perf PRs reverted ("new").
#   ruby others.rb DIR NEW NEW2 OLD OLD2 NEW_TREE OLD_TREE MAIN_SHA MERGE_BASE
# DIR holds one directory per label with census-shaped JSON files ("sites"
# with RAILS/file and line); files every label has are summed. Lines shift
# between the trees, so a site is keyed by its file and the nearest `def` at
# or above its line in its own tree. Per method, the change is the mean of
# the new pair minus the mean of the old pair; the A/A column is the mean
# absolute difference inside the pairs.
# Blame: the method's lines in the new tree, with our revert commits
# (MAIN_SHA..NEW_TREE HEAD) ignored so restored lines go to their original
# commit. Each line newer than the merge base maps to the oldest first-parent
# merge on main containing it ("#N" from its subject). A method main does not
# define is "method not on main"; one whose lines all predate the merge base
# is "unchanged lines" (its allocations moved because of code it calls or
# its callers, so the blame does not name the cause).
require "json"
require "open3"
require "tempfile"

dir, *labels = ARGV.first(5)
new_tree, old_tree, main_sha, merge_base = ARGV[5, 4]
abort "usage: others.rb DIR NEW NEW2 OLD OLD2 NEW_TREE OLD_TREE MAIN_SHA MERGE_BASE" unless merge_base

def git(dir, *args) = Open3.capture2("git", "-C", dir, *args).first

defs = {}
method_of = lambda do |tree, file, line|
  defs[[tree, file]] ||= (File.readlines(File.join(tree, file)) rescue []).each_with_index.filter_map do |l, i|
    [i + 1, l[/^\s*def\s+((?:self\.)?[^\s(;=]+=?)/, 1]] if l.match?(/^\s*def\s/)
  end
  d = defs[[tree, file]].reverse.find { _1[0] <= line }
  d ? d[1] : "(top level)"
end
method_range = lambda do |tree, file, name|
  ds = defs[[tree, file]] || []
  i = ds.index { _2 == name } or return nil
  (ds[i][0]...(ds[i + 1]&.first || ds[i][0] + 40))
end

sites = lambda do |label, file, tree|
  JSON.parse(File.read(File.join(dir, label, file)))["workloads"].each_with_object(Hash.new(0.0)) do |w, acc|
    w["sites"].each do |s|
      next unless s["file"].start_with?("RAILS/")
      f = s["file"].delete_prefix("RAILS/")
      acc[[f, method_of.(tree, f, s["line"])]] += s["objects_per_op"]
    end
  end
end
files = Dir[File.join(dir, labels[0], "*.json")].map { File.basename(_1) }
          .select { |f| labels.all? { File.exist?(File.join(dir, _1, f)) } }
trees = [new_tree, new_tree, old_tree, old_tree]
n1, n2, o1, o2 = labels.zip(trees).map { |l, t| files.map { sites.(l, _1, t) }.reduce { |a, b| a.merge(b) { |_, x, y| x + y } } }

ignore = Tempfile.new("revs")
ignore.write(git(new_tree, "rev-list", "#{main_sha}..HEAD"))
ignore.flush
blames = {}
blame = lambda do |file|
  blames[file] ||= git(new_tree, "blame", "--porcelain", "--ignore-revs-file", ignore.path, "--", file).each_line.with_object({}) do |l, h|
    m = l.match(/\A(\h{40}) \d+ (\d+)/) and h[m[2].to_i] = m[1]
  end
end
prs = {}
pr_of = lambda do |commit|
  prs[commit] ||=
    if system("git", "-C", new_tree, "merge-base", "--is-ancestor", commit, merge_base)
      nil
    else
      merge = git(new_tree, "rev-list", "--first-parent", "--merges", "--ancestry-path", "#{commit}..#{main_sha}").split.last
      subject = git(new_tree, "log", "-1", "--format=%s", merge || commit).strip
      subject[/#(\d+)/] ? "##{$1}" : "#{(merge || commit)[0, 10]} #{subject[0, 50]}"
    end
end

rows = (n1.keys | n2.keys | o1.keys | o2.keys).filter_map do |k|
  d = (n1[k] + n2[k]) / 2 - (o1[k] + o2[k]) / 2
  next if d.abs < 0.5
  aa = ((n1[k] - n2[k]).abs + (o1[k] - o2[k]).abs) / 2
  method_of.(new_tree, k[0], 1) # loads the file's defs
  range = method_range.(new_tree, *k)
  who =
    if !range
      "method not on main"
    else
      b = blame.(k[0])
      counts = range.filter_map { (c = b[_1]) && pr_of.(c) }.tally
      counts.empty? ? "unchanged lines" : counts.sort_by { -_2 }.first(3).map { |p, n| "#{p} (#{n} lines)" }.join(", ")
    end
  { site: "#{k[0]} #{k[1]}", delta: d, aa: aa, who: who }
end

fmt = ->(r) { format("%+.1f (A/A %.1f) %s — %s", r[:delta], r[:aa], r[:site], r[:who]) }
puts JSON.pretty_generate(
  files: files, total_delta: rows.sum { _1[:delta] }.round(1),
  top_saving: rows.sort_by { _1[:delta] }.first(20).map(&fmt),
  top_cost: rows.sort_by { -_1[:delta] }.first(20).map(&fmt)
)
