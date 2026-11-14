# frozen_string_literal: true

# ours_survive.rb RAILS_GIT SINCE HEAD: for each of our merged rails/rails PRs
# (first-parent merges "from thomasklemm/..." in SINCE..HEAD), the share of the
# lib lines it added that are still in the same file at HEAD, and the commits
# since the merge that touched those files' changed lines. A PR whose lines
# are gone was reverted or rewritten upstream.
dir, since, head = ARGV
git = ->(*a) { IO.popen(["git", "-C", dir, *a], &:read) }
git.("log", "--first-parent", "--format=%H %cs %s", "#{since}..#{head}").lines.each do |l|
  sha, date, subject = l.chomp.split(" ", 3)
  next unless subject =~ /#(\d+) from thomasklemm\//
  pr = $1
  added = Hash.new { |h, k| h[k] = [] }
  file = nil
  git.("diff", "--unified=0", "#{sha}^1", sha, "--", "*/lib/*").each_line do |d|
    if d.start_with?("+++ b/") then file = d.chomp.delete_prefix("+++ b/")
    elsif d.start_with?("+") && !d.start_with?("+++") && file
      text = d[1..].strip
      added[file] << text unless text.empty? || text.start_with?("#") || ["end", "else", ")", "}", "]", "})", "end)"].include?(text)
    end
  end
  next if added.empty?
  total = added.values.sum(&:size)
  kept = added.sum do |f, lines|
    now = git.("show", "#{head}:#{f}").lines.map(&:strip)
    lines.count { now.include?(_1) }
  end
  later = git.("log", "--format=%h %an %s", "#{sha}..#{head}", "--", *added.keys).lines.map(&:chomp)
  printf("#%s %s kept %d/%d lib lines%s\n", pr, date, kept, total, kept < total ? "  <-- changed" : "")
  later.first(6).each { puts "    later on these files: #{_1}" } if kept < total
end
