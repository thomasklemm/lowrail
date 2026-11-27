# ruby verify.rb SEARCH.jsonl NAME... > verified.txt: for each query mentioning NAME, fetch every hit outside Rails
# copies (default branch, Contents API) and keep only lines that define exactly NAME (`def NAME` or `def self.NAME`).
# Visibility is guessed from the nearest preceding bare private/protected/public at the definition's indentation or
# less (a `private def` prefix counts); `class << self` / `class_methods do` is noted. Uses repos.json from rank.rb.
require "json"
require "base64"
file, *names = ARGV
cache = JSON.parse(File.read(File.join(__dir__, "repos.json")))
rails_copy = %r{(\A|/)(activerecord|activemodel|actionpack|actionview|activesupport|activejob|actionmailer|railties)(-[\d.]+)?/(lib|test)/|(\A|/)(gems|vendor|bundle)/|\A(lib/)?(active_record|active_model|action_view|action_controller|abstract_controller|active_support)/}
queries = File.readlines(file).map { JSON.parse(_1) }
names.each do |name|
  re = /^(\s*)(private |protected )?def (self\.)?#{Regexp.escape(name)}(?![\w?!=])/
  hits = queries.select { _1["query"].include?("def #{name}\"") || _1["query"].include?("def self.#{name}\"") }.flat_map { _1["hits"] || [] }
  hits = hits.reject { rails_copy.match?(_1["path"]) || _1["repo"] == "rails/rails" }.uniq { [_1["repo"], _1["path"]] }
  puts "\n## #{name}: #{hits.size} candidate files"
  rows = hits.filter_map do |h|
    src = Base64.decode64(IO.popen(["gh", "api", "repos/#{h["repo"]}/contents/#{h["path"]}", "--jq", ".content"], err: File::NULL, &:read))
    lines = src.lines
    found = lines.each_index.select { re.match?(lines[_1]) }
    next if found.empty?
    found.map do |i|
      indent = lines[i][re, 1].size
      vis = lines[i][re, 2]&.strip
      vis ||= lines[0...i].reverse.find { |l| l =~ /^(\s*)(private|protected|public)\s*$/ && $1.size <= indent && $1.size >= indent - 2 }&.strip
      ctx = lines[0...i].reverse.find { |l| l =~ /class << self|class_methods do|module ClassMethods|^\s*(class|module) / }&.strip
      [cache.dig(h["repo"], "stars").to_i, cache.dig(h["repo"], "pushed").to_s[0, 10], cache.dig(h["repo"], "archived"), h["repo"], "#{h["path"]}:#{i + 1}", vis || "public", ctx, lines[i].strip]
    end
  end.flatten(1)
  rows.sort_by { -_1[0] }.each do |stars, pushed, archived, repo, loc, vis, ctx, line|
    puts "#{stars.to_s.rjust(6)}  #{pushed}#{archived ? " archived" : ""}  #{repo}  #{loc}  [#{vis}; #{ctx}]  #{line}"
  end
end
