# gems-engine.rb LIB : an engine profiled in place, so the attribution root is itself a path gem (G row = root), with
# a view under app/views/gems/: where the report puts its lines.
$LOAD_PATH.unshift(ARGV.fetch(0)); require "lowrail/profile_report"; require "tmpdir"; require "fileutils"; require "json"
Dir.mktmpdir do |dir|
  %w[run1 run2].each do |run|
    FileUtils.mkdir_p(File.join(dir, run))
    rows = ["# lowrail-profile 3\trequests=4\tobjects=32\tdropped=0\twindows=4,0,0,0\tpid=1\troot=/engine\tapp_root=/engine",
      "P\t0\t/engine/app/views/gems/index.html.erb", "P\t1\t/engine/app/models/m.rb",
      "0\t5\tString\t12\t4\t0\t0\trequest", "1\t9\tString\t20\t4\t0\t0\trequest",
      "A\trequest\tGemsController#index\t4\t32\t0", "G\tmy_engine\t/engine"]
    File.write(File.join(dir, run, "1.tsv"), rows.join("\n") << "\n")
  end
  report = Lowrail::ProfileReport.new(dir)
  report.sites.each { puts "  #{_1.key}:#{_1.line} => #{_1.group}" }
  puts "  unclassified: #{JSON.parse(JSON.generate(report.to_h))["unclassified"].inspect}"
end
