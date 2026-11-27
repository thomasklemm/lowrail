# ruby warnings.rb BASE_LABEL HEAD_LABEL [MODE] -- warning lines HEAD prints that BASE never prints, per app.
base, head, mode = ARGV
mode ||= "interpw"
logs = File.expand_path("~/rdiff/logs")
norm = lambda do |l|
  l.gsub(%r{/home/user/rdiff/rubies/[^/]+/lib/ruby/(gems/)?[\d.+]+/}, "RUBY/")
    .gsub(%r{/home/user/rdiff/work/[^/]+/[^/]+/}, "APP/").gsub(%r{/home/user/workspace/repo/\.corpus/[^/]+/}, "APP/")
    .gsub(/0x\h+/, "0x").gsub(/#\d+/, "#N").gsub(/\b\d{2,}\b/, "N").gsub(/x86_64-linux/, "ARCH").strip
end
pick = ->(f) { File.exist?(f) ? File.foreach(f, chomp: true).map { _1.scrub }.grep(/warning:|deprecat/i).map(&norm).tally : nil }
Dir[File.join(logs, head, "*-#{mode}.log")].sort.each do |hf|
  app = File.basename(hf).delete_suffix("-#{mode}.log")
  b = pick.(File.join(logs, base, File.basename(hf)))
  next puts("#{app}: no base log") unless b
  h = pick.(hf)
  only = h.reject { |k, _| b.key?(k) }
  gone = b.reject { |k, _| h.key?(k) }
  puts "== #{app}: head #{h.size} distinct warning lines, base #{b.size}; head only #{only.size}, base only #{gone.size}"
  only.sort_by { -_2 }.first(30).each { |k, n| puts "  + #{n}x #{k[0, 260]}" }
  gone.sort_by { -_2 }.first(10).each { |k, n| puts "  - #{n}x #{k[0, 260]}" }
end
