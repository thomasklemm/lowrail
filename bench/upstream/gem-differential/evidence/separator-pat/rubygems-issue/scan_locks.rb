# Scan the default-branch Gemfile.lock of every gem repo in gems.json: BUNDLED WITH and PATH/GIT sections.
require "json"
require "open3"
require "base64"

gems = JSON.parse(File.read(ARGV.fetch(0)))
out = []
gems.each do |g|
  repo = g["repo"].to_s[%r{github\.com/([^/]+/[^/#?]+)}, 1]&.sub(/\.git\z/, "")
  next unless repo
  info, st = Open3.capture2("gh", "api", "repos/#{repo}", "--jq", "[.full_name,.default_branch,.archived,.pushed_at,.stargazers_count]|@json")
  next warn("#{repo}: repo api failed") unless st.success?
  full, branch, archived, pushed, stars = JSON.parse(info)
  sha, = Open3.capture2("gh", "api", "repos/#{full}/commits/#{branch}", "--jq", ".sha")
  sha = sha.strip
  body, st = Open3.capture2("gh", "api", "repos/#{full}/contents/Gemfile.lock?ref=#{sha}", "--jq", ".content")
  lock = st.success? ? Base64.decode64(body) : nil
  bw = lock && lock[/^BUNDLED WITH\n\s+(\S+)/, 1]
  sections = lock ? lock.scan(/^(PATH|GIT)$/).flatten.tally : {}
  rec = { name: g["name"], rank: g["rank"], downloads: g["downloads"], repo: full, branch: branch, sha: sha,
          archived: archived, pushed_at: pushed, stars: stars, lock: !lock.nil?, bundled_with: bw, sections: sections,
          diff_status: g["status"] }
  out << rec
  warn rec.to_json
end
File.write(ARGV.fetch(1), JSON.pretty_generate(out))
