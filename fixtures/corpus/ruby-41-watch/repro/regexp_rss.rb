rss = -> { File.read("/proc/self/statm").split[1].to_i * 4096 }
GC.start; GC.compact rescue nil
keep = []
b = rss.()
200_000.times { |i| keep << Regexp.new("^host#{i}$", Regexp::IGNORECASE) }
GC.start
printf("RSS per retained Regexp: %.0f B\n", (rss.() - b).fdiv(keep.size))
