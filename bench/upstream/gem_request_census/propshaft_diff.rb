# frozen_string_literal: true

# Differential check for P1 (docs/upstream/gem-request-census.md): print every
# logical path, key encoding and asset path that Propshaft::LoadPath builds for
# 24 spellings of the same load paths. Run once per checkout and compare:
#   ruby propshaft_diff.rb PROPSHAFT_LIB > base.txt   (inside a bundle with Rails)
require "tmpdir"
$LOAD_PATH.unshift ARGV.shift
require "active_support/all"
require "action_dispatch/http/mime_type"
module Propshaft; end
require "propshaft/load_path"

Dir.mktmpdir do |dir|
  Dir.chdir(dir)
  %w[app/assets/a.css app/assets/sub/b.js app/assets/sub/ö.png app/assets/sub/deep/c.svg app/assets/.hidden
    other/a.css other/z.txt ü\ dir/x.css].each { FileUtils.mkdir_p(File.dirname(_1)); File.write(_1, _1) }
  File.symlink("../app/assets/sub", "other/linked")
  roots = [["app/assets"], ["./app/assets"], ["app/assets/"], ["app//assets"], ["app/../app/assets"], ["app/./assets/"],
    [Dir.pwd + "/app/assets"], ["."], ["other"], ["ü dir"], ["app/assets", "other"], ["other", "app/assets/sub"],
    [Pathname.new("app/assets")], ["app/assets/sub/../sub"], ["app/assets//"], ["app/assets/."], ["app/assets/./"],
    ["app/assets/sub/.."], [".//app/assets"], ["app/assets///"], ["./"], ["/" + Dir.pwd[1..] + "//app/assets"],
    ["app/assets/sub/../"], ["app/assets/../assets/."]]
  roots.each do |r|
    lp = Propshaft::LoadPath.new(r, compilers: nil)
    out = lp.send(:assets_by_path).map do |k, a|
      [k, k.encoding.to_s, a.logical_path.to_s, a.logical_path.to_s.encoding.to_s, a.logical_path.class, a.path.to_s.delete_prefix(dir)]
    end
    puts "#{r.inspect.gsub(dir, "TMP")} => #{out.inspect}"
  end
end
