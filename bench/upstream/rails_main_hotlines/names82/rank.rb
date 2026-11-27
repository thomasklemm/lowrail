# ruby rank.rb SEARCH.jsonl... > ranked.txt: per query, the hit repos that aren't Rails copies (vendored or forked
# framework paths), with stars, last push and archived flag from the GitHub API (cached in repos.json), most stars first.
require "json"
cache_path = File.join(__dir__, "repos.json")
cache = File.exist?(cache_path) ? JSON.parse(File.read(cache_path)) : {}
rails_copy = %r{(\A|/)(activerecord|activemodel|actionpack|actionview|activesupport|activejob|actionmailer|railties)(-[\d.]+)?/(lib|test)/|(\A|/)(gems|vendor|bundle)/|\A(lib/)?(active_record|active_model|action_view|action_controller|abstract_controller|active_support)/}
ARGV.flat_map { File.readlines(_1).map { |l| JSON.parse(l) } }.each do |q|
  next puts("\n## #{q["query"]}: search error") if q["error"]
  hits = q["hits"].reject { rails_copy.match?(_1["path"]) || _1["repo"] == "rails/rails" }
  hits.map { _1["repo"] }.uniq.each do |repo|
    cache[repo] ||= JSON.parse(IO.popen(["gh", "api", "repos/#{repo}", "--jq", "{stars: .stargazers_count, pushed: .pushed_at, archived: .archived, fork: .fork}"], &:read)) rescue { "stars" => -1 }
  end
  puts "\n## #{q["query"]}: #{q["total"]} total, #{hits.size} of the first #{q["hits"].size} outside Rails copies"
  hits.group_by { _1["repo"] }.sort_by { |r, _| -cache.dig(r, "stars").to_i }.each do |repo, hs|
    m = cache[repo]
    puts "#{m["stars"].to_s.rjust(6)}  #{m["pushed"].to_s[0, 10]}#{m["archived"] ? " archived" : ""}#{m["fork"] ? " fork" : ""}  #{repo}  #{hs.map { _1["path"] }.first(3).join(", ")}"
  end
end
File.write(cache_path, JSON.pretty_generate(cache.sort.to_h))
