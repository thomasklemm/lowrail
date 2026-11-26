# gems-dir.rb LIB : how the report of LIB classifies lines of app files under a directory named gems/ that is not
# a path gem (a GemsController's views, app/models/gems/), beside a path gem in gems/ and an ordinary app file.
$LOAD_PATH.unshift(ARGV.fetch(0)); require "lowrail/profile_report"; require "tmpdir"; require "fileutils"; require "json"
Dir.mktmpdir do |dir|
  %w[run1 run2].each do |run|
    FileUtils.mkdir_p(File.join(dir, run))
    rows = ["# lowrail-profile 3\trequests=4\tobjects=60\tdropped=0\twindows=4,0,0,0\tpid=1\troot=/app\tapp_root=/app",
      "P\t0\t/app/gems/foo/lib/foo.rb", "P\t1\t/app/app/views/gems/index.html.erb", "P\t2\t/app/app/models/gems/ruby.rb", "P\t3\t/app/app/models/m.rb",
      "0\t3\tString\t20\t4\t0\t0\trequest", "1\t5\tString\t12\t4\t0\t0\trequest", "2\t7\tString\t8\t4\t0\t0\trequest", "3\t9\tString\t20\t4\t0\t0\trequest",
      "A\trequest\tGemsController#index\t4\t60\t0", "G\tfoo\t/app/gems/foo"]
    File.write(File.join(dir, run, "1.tsv"), rows.join("\n") << "\n")
  end
  report = Lowrail::ProfileReport.new(dir)
  report.sites.each { puts "  #{_1.key}:#{_1.line} => #{_1.group}" }
  h = JSON.parse(JSON.generate(report.to_h))
  puts "  unclassified: #{h["unclassified"].inspect}"
end
