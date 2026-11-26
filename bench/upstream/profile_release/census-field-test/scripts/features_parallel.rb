# ruby features_parallel.rb OUTDIR BASE SETS [EXTRA_REJECT]: for suites with parallel workers, whose per-process load order
# depends on which tests each worker draws. Per run: the parent process (lowest PID with the most features loaded before
# the fork) against BASE's parent, in order; and the union of every process's files against BASE's union, as a set.
# Outside Lowrail, Bundler and RubyGems, as M4's features_cmp.rb.
dir, base, sets, extra = ARGV
extra &&= Regexp.new(extra)
norm = ->(f) { File.readlines(f, chomp: true).reject { _1.include?("/lowrail") || _1.match?(%r{/bundler[-/.]|/rubygems[/.]|rubygems/}) || (extra && _1.match?(extra)) } }
runs = lambda do |set|
  files = Dir["#{dir}/#{set}.features/*.txt"]
  files = files.select { File.basename(_1).start_with?("run") } unless set.match?(/\A(plain|off)/)
  files.group_by { File.basename(_1)[/\A(run\d+)-/, 1] || "all" }.transform_values do |fs|
    lists = fs.sort_by { File.basename(_1)[/(\d+)\.txt/, 1].to_i }.map(&norm).reject { _1.size < 100 }
    { parent: lists.first, union: lists.flatten.uniq.sort, n: lists.size }
  end
end
b = runs.(base).values.first or abort "no #{base} processes"
puts "base #{base}: #{b[:n]} processes, parent #{b[:parent].size} files, union #{b[:union].size}"
sets.split(",").each do |s|
  runs.(s).each do |run, r|
    po = r[:parent] == b[:parent]
    un = r[:union] == b[:union]
    line = "#{s} #{run}: #{r[:n]} processes; parent #{po ? "identical in order" : "DIFFERS"}; union #{un ? "identical" : "DIFFERS"}"
    line += " (extra #{(r[:union] - b[:union]).first(3)}, missing #{(b[:union] - r[:union]).first(3)})" unless un
    unless po
      i = r[:parent].zip(b[:parent]).index { _1 != _2 }
      line += " (parent first differs at #{i}: #{r[:parent][i].to_s.split("/").last(2).join("/")} vs #{b[:parent][i].to_s.split("/").last(2).join("/")}; same set: #{r[:parent].sort == b[:parent].sort})"
    end
    puts line
  end
end
