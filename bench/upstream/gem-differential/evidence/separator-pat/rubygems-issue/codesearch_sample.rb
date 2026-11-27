# Sample committed Gemfile.lock files with a PATH or GIT section from GitHub code search; BUNDLED WITH per file.
require "json"
require "open3"
require "base64"
require "time"

def gh(*args)
  out, st = Open3.capture2("gh", "api", *args)
  st.success? ? out : nil
end

rows = []
[['filename:Gemfile.lock "remote: ." "BUNDLED WITH"', "PATH"], ['filename:Gemfile.lock "revision:" "BUNDLED WITH"', "GIT"]].each do |q, kind|
  (1..2).each do |page|
    res = gh("-X", "GET", "search/code", "-f", "q=#{q}", "-f", "per_page=100", "-f", "page=#{page}")
    next warn("search failed #{kind} #{page}") unless res
    data = JSON.parse(res)
    warn "#{kind} total_count=#{data["total_count"]}" if page == 1
    data["items"].each do |it|
      repo = it["repository"]["full_name"]
      meta = gh("repos/#{repo}", "--jq", "[.pushed_at,.stargazers_count,.archived,.fork]|@json")
      pushed, stars, archived, fork = meta ? JSON.parse(meta) : []
      body = gh("repos/#{repo}/contents/#{it["path"]}", "--jq", ".content")
      lock = body && Base64.decode64(body)
      bw = lock && lock[/^BUNDLED WITH\n\s+(\S+)/, 1]
      rows << { kind:, repo:, path: it["path"], bundled_with: bw, pushed_at: pushed, stars:, archived:, fork:,
                has_path: lock&.match?(/^PATH$/), has_git: lock&.match?(/^GIT$/) }
    end
    sleep 7
  end
end
File.write(ARGV.fetch(0), JSON.pretty_generate(rows))
