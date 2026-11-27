# ruby attr3.rb ACTION RUN_DIR... : format-3 attributed runs; warm objects per warm window of ACTION by site,
# by app line and by (site, app line), the rows that differ most between the runs.
action = ARGV.shift
short = ->(p) { p.sub(%r{.*/gems/}, "").sub(%r{.*/ft-[^/]+/}, "APP/").sub(%r{.*/lib/ruby/\d\.\d\.\d/}, "RUBY/") }
per = ARGV.map do |dir|
  sites, apps, pairs = Hash.new(0.0), Hash.new(0.0), Hash.new(0.0)
  windows = procs = 0
  Dir["#{dir}/*.tsv"].each do |f|
    paths = {}
    File.foreach(f, chomp: true) do |l|
      c = l.split("\t")
      case c[0]
      when "P" then paths[c[1]] = short.(c[2])
      when "A" then (windows += c[3].to_i; procs += 1) if c[2] == action
      when "@"
        next unless c[2] == action
        w = c[7].to_i - c[8].to_i
        s, a = "#{paths[c[3]]}:#{c[4]}", "#{paths[c[5]]}:#{c[6]}"
        sites[s] += w; apps[a] += w; pairs["#{s} <- #{a}"] += w
      end
    end
  end
  d = (windows - procs).to_f
  [sites, apps, pairs].each { |h| h.transform_values! { _1 / d } }
  [dir, d, sites, apps, pairs]
end
per.each { puts "#{_1[0]}: #{_1[1].to_i} warm windows, total #{_1[2].values.sum.round(1)}" }
{ "sites" => 2, "app lines" => 3, "pairs" => 4 }.each do |title, i|
  keys = per.map { _1[i].keys }.reduce(:|)
  rows = keys.map { |k| [k, per.map { _1[i][k] }] }.sort_by { |_, v| -(v.max - v.min) }
  puts "#{title}:"
  rows.first((ENV["N"] || 15).to_i).each { |k, v| puts format("  %-110s %s", k[0, 110], v.map { _1.round(1) }.inspect) }
end
