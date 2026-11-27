# ruby mutants.rb URI_DIR: copies URI_DIR per mutant, applies one replacement to lib/uri/common.rb, and prints which
# test_decode_* assertions fail (file:line) on each Ruby/prelude listed in RUNS.
require "fileutils"
src = File.expand_path(ARGV.fetch(0))
here = __dir__
BASE_LIB = `git -C #{src} show 48cda77:lib/uri/common.rb`
M = {
  "base (48cda77 lib, new tests)" => [:base],
  "uri_component decodes +" => ["CGI.unescapeURIComponent(bytes, Encoding::BINARY)", "CGI.unescape(bytes, Encoding::BINARY)"],
  "www_form keeps +" => ["CGI.unescape(bytes, Encoding::BINARY)", "CGI.unescapeURIComponent(bytes, Encoding::BINARY)"],
  "CGI picks the result encoding" => [["yield(str.b).force_encoding(enc)", "yield(str.b, enc)"], ["{|bytes| CGI.unescape(bytes, Encoding::BINARY) }", "{|bytes, e| CGI.unescape(bytes, e) }"]],
  "no force_encoding" => ["yield(str.b).force_encoding(enc)", "yield(str.b)"],
  "lone % accepted" => ["    raise ArgumentError, \"invalid %-encoding (\#{str})\" if /%(?!\\h\\h)/.match?(str)\n", ""],
  "lone % check misses %zz" => ["/%(?!\\h\\h)/", "/%(?!\\h?\\h)/"],
  "no b copy" => ["yield(str.b)", "yield(str)"],
  "lone % check takes \\w for hex" => ["/%(?!\\h\\h)/", "/%(?!\\w\\w)/"],
  "fallback gsub! (nil when nothing to decode)" => ["bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_)", "bytes.gsub!(/%\\h\\h/, TBLDECWWWCOMP_)"],
  "fallback decodes +" => ["bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_)", "bytes.gsub(/\\+|%\\h\\h/, TBLDECWWWCOMP_)"],
  "fallback upper-case hex only" => ["bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_)", "bytes.gsub(/%[0-9A-F]{2}/, TBLDECWWWCOMP_)"],
  "native check dropped (Ruby decoder used)" => [" && !CGI.method(:unescapeURIComponent).source_location", ""],
}
RUNS = { "4.0.10" => "", "4.0.10 no C decoder" => "-r#{here}/no_c_decoder.rb", "2.5.9" => "", "truffleruby-40.0.0" => "" }
M.each do |name, edits|
  dir = "/tmp/mut/#{name.gsub(/\W+/, "_")}"
  FileUtils.rm_rf(dir); FileUtils.mkdir_p(dir)
  FileUtils.cp_r(%w[lib test].map { "#{src}/#{_1}" }, dir)
  lib = "#{dir}/lib/uri/common.rb"
  if edits == [:base]
    File.write(lib, BASE_LIB)
  else
    edits = [edits] unless edits.first.is_a?(Array)
    code = File.read(lib)
    edits.each { |from, to| code.include?(from) or abort "#{name}: #{from} not found"; code = code.sub(from, to) }
    File.write(lib, code)
  end
  RUNS.each do |run, pre|
    ruby = "#{`mise where ruby@#{run.split.first}`.strip}/bin/ruby"
    out = `cd #{dir} && #{ruby} #{pre} -Ilib -Itest/lib -rhelper test/uri/test_common.rb -n /test_decode_/ 2>&1`
    out = out.scrub
    fails = out.scan(%r{test_common\.rb:(\d+):in .*test_decode_(\w+)}).uniq.map { |l, m| "#{m}:#{l}" }
    summary = out[/^\d+ tests.*?failures, \d+ errors/] || out.lines.last(2).join.strip
    puts "#{name} | #{run} | #{summary.sub(/, \d+ pendings.*/, "")} | #{fails.join(" ")}"
  end
end
