# gen.rb SRC OUT WORKERS SCALE: a large capture from a real one (format 3).
# Each output file w takes template file w % n and repeats its rows SCALE times
# (variant v): window names get a suffix shared by part of the workers, site
# rows of variant v > 0 move by 10000 * v lines (every third variant only).
require "fileutils"
src, out, workers, scale = ARGV[0], ARGV[1], Integer(ARGV[2]), Integer(ARGV[3])
FileUtils.rm_rf(out)
FileUtils.mkdir_p(out)
%w[command.txt capture.json].each { FileUtils.cp(File.join(src, _1), out) if File.exist?(File.join(src, _1)) }
Dir["#{src}/run*"].sort.each do |run|
  templates = Dir["#{run}/*.tsv"].sort
  dir = File.join(out, File.basename(run))
  FileUtils.mkdir_p(dir)
  workers.times do |w|
    lines = File.readlines(templates[w % templates.size], chomp: true)
    header = lines.shift
    File.open(File.join(dir, "#{100_000 + w}.tsv"), "w") do |f|
      f.puts header.sub(/\tpid=\d+/, "\tpid=#{100_000 + w}")
      lines.each { f.puts(_1) if _1.start_with?("P\t", "G\t") }
      scale.times do |v|
        tag = (v + w * 3) % (scale * 2)
        lines.each do |row|
          fields = row.split("\t")
          case fields[0]
          when "P", "G" then next
          when "A"
            fields[2] = "#{fields[2]}~#{tag}" if v > 0
          when "@"
            fields[2] = "#{fields[2]}~#{tag}" if v > 0
          else
            next if v > 0 && v % 3 != 0
            fields[1] = (Integer(fields[1]) + 10_000 * v).to_s
          end
          f.puts fields.join("\t")
        end
      end
    end
  end
end
