# ruby mutants.rb DIR: one edit to DIR/lib/uri/common.rb per mutant, then DIR's test_decode_* tests on each
# Ruby/prelude in RUNS. Prints the failing assertions (method:line), or "survives".
require "fileutils"
src = File.expand_path(ARGV.fetch(0))
ur1 = "/home/user/workspace/repo/bench/upstream/outside_leads/ur1"
MRI = "#{Dir.home}/.local/share/mise/installs/ruby/4.0.9/bin/ruby"
TR = "/tmp/rt/truffleruby-community-40.0.0-linux-amd64/bin/ruby"
RUNS = {
  "4.0.9" => [MRI, ""],
  "4.0.9 no C decoder" => [MRI, "-r#{ur1}/rework/tests/no_c_decoder.rb"],
  "truffleruby-40.0.0" => [TR, ""],
}
E = "Encoding::ASCII_8BIT"
M = {
  "unchanged" => [],
  "no b copy" => [["yield(str.b)", "yield(str)"]],
  "no force_encoding" => [["yield(str.b).force_encoding(enc)", "yield(str.b)"]],
  "CGI picks the result encoding" => [["yield(str.b).force_encoding(enc)", "yield(str.b, enc)"],
    ["{|bytes| CGI.unescape(bytes, #{E}) }", "{|bytes, e| CGI.unescape(bytes, e) }"],
    ["{|bytes| CGI.unescapeURIComponent(bytes, #{E}) }", "{|bytes, e| CGI.unescapeURIComponent(bytes, e) }"]],
  "lone % accepted" => [["    raise ArgumentError, \"invalid %-encoding (\#{str})\" if /%(?!\\h\\h)/.match?(str)\n", ""]],
  "lone % check takes \\w for hex" => [["/%(?!\\h\\h)/", "/%(?!\\w\\w)/"]],
  "lone % check accepts one hex digit" => [["/%(?!\\h\\h)/", "/%(?!\\h?\\h)/"]],
  "native www_form keeps +" => [["CGI.unescape(bytes, #{E})", "CGI.unescapeURIComponent(bytes, #{E})"]],
  "native uri_component decodes +" => [["CGI.unescapeURIComponent(bytes, #{E})", "CGI.unescape(bytes, #{E})"]],
  "fallback www_form keeps +" => [["bytes.gsub(/\\+|%\\h\\h/, TBLDECWWWCOMP_)", "bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_)"]],
  "fallback uri_component decodes +" => [["bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_)", "bytes.gsub(/\\+|%\\h\\h/, TBLDECWWWCOMP_)"]],
  "fallback www_form gsub!" => [["bytes.gsub(/\\+|%\\h\\h/, TBLDECWWWCOMP_)", "bytes.gsub!(/\\+|%\\h\\h/, TBLDECWWWCOMP_)"]],
  "fallback uri_component gsub!" => [["bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_)", "bytes.gsub!(/%\\h\\h/, TBLDECWWWCOMP_)"]],
  "fallback uri_component upper-case hex only" => [["bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_)", "bytes.gsub(/%[0-9A-F]{2}/, TBLDECWWWCOMP_)"]],
  "native check dropped" => [[" && !CGI.method(:unescapeURIComponent).source_location", ""]],
}
M.each do |name, edits|
  dir = "/tmp/fable-mut/#{File.basename(src)}/#{name.gsub(/\W+/, "_")}"
  FileUtils.rm_rf(dir); FileUtils.mkdir_p(dir)
  FileUtils.cp_r(%w[lib test].map { "#{src}/#{_1}" }, dir)
  lib = "#{dir}/lib/uri/common.rb"
  code = File.read(lib)
  skip = edits.any? { |from, _| !code.include?(from) }
  edits.each { |from, to| code = code.sub(from) { to } } unless skip
  File.write(lib, code)
  RUNS.each do |run, (ruby, pre)|
    next puts("#{name} | #{run} | not applicable (no such code)") if skip
    out = `cd #{dir} && #{ruby} #{pre} -Ilib -Itest/lib -rhelper test/uri/test_common.rb -n /test_decode_/ 2>&1`.scrub
    fails = out.scan(%r{test_common\.rb:(\d+):in .*test_decode_(\w+)}).uniq.map { |l, m| "#{m}:#{l}" }
    died = out[/^\d+ tests/] ? nil : "process died: #{out[/\S*Exception\S*|\S*Error\S*/]}"
    puts "#{name} | #{run} | #{died || (fails.empty? ? "survives" : fails.join(" "))}"
  end
end
