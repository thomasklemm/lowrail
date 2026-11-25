# ruby ledger_check.rb REPORT.json...: every ledger match in the reports (rows, mode rows), checked against the
# pull request's live diff on GitHub (gh api): the line's source text must be a removed or added line of that file.
require "json"; require "open3"
seen = {}
ARGV.each do |report|
  j = JSON.parse(File.read(report))
  (j["rows"] + j["mode_rows"]).each do |r|
    r["ledger"].each do |label|
      ref = label[/\A(\S*#\d+)/, 1]
      repo, number = ref.include?("/") ? ref.split("#") : ["rails/rails", ref.delete("#")]
      key = [r["site"], ref]
      next if seen[key]
      files, = Open3.capture2("gh", "api", "--paginate", "repos/#{repo}/pulls/#{number}/files?per_page=100")
      files = JSON.parse(files.gsub("][", ","))
      path = r["site"].sub(%r{\ARAILS/}, "").sub(%r{\AGEM/[^/]+/}, "").sub(/:\d+\z/, "")
      file = files.find { |f| f["filename"] == path || f["filename"].end_with?("/#{path}") }
      text = r["text"].to_s
      hit = file && file["patch"].to_s.lines.any? { |l| l.start_with?("-", "+") && l[1..].strip == text }
      seen[key] = hit
      puts "#{hit ? "OK  " : "MISS"} #{report.split("/")[-3]}: #{r["site"]} `#{text[0, 60]}` #{label}"
    end
  end
end
puts "#{seen.values.count(true)} of #{seen.size} matches confirmed in the pull request's diff"
