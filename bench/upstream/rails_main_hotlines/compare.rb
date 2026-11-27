# ruby compare.rb OUT APP...: per-test outcomes of r81 against main from each tree's profiled.outcomes (outcomes.rb,
# both profiled runs tallied). Minitest lines are "Class#test = R" (R one of . S F E); an RSpec documentation line
# fails when it ends in "(FAILED)". A test regresses when it passed in every r81 run and failed in every main run.
out = ARGV.shift
def load(path)
  return nil unless File.exist?(path)
  File.readlines(path, chomp: true).each_with_object(Hash.new { |h, k| h[k] = Hash.new(0) }) do |line, acc|
    count, outcome = line.split("\t", 2)
    next unless outcome
    if outcome =~ /\A(.+) = ([.SFE])\z/
      acc[$1][$2 == "." ? :pass : $2 == "S" ? :skip : :fail] += count.to_i
    else
      name = outcome.sub(/ \(FAILED\)\z/, "")
      acc[name][outcome.end_with?("(FAILED)") ? :fail : :pass] += count.to_i
    end
  end
end
puts "| App | tests r81 | failing r81 | tests main | failing main | pass r81, fail main | fail r81, pass main |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"
details = []
ARGV.each do |app|
  base, head = %w[r81 main].map { load(File.join(out, app, _1, "profiled.outcomes")) }
  unless base && head
    puts "| #{app} | #{base ? base.size : "none"} | | #{head ? head.size : "none"} | | | |"
    next
  end
  failing = ->(t) { t.count { |_, c| c[:fail] > 0 } }
  regress = base.keys.select { |k| base[k][:fail].zero? && base[k][:pass] > 0 && head.key?(k) && head[k][:pass].zero? && head[k][:fail] > 0 }
  fixed = base.keys.select { |k| base[k][:pass].zero? && base[k][:fail] > 0 && head.key?(k) && head[k][:fail].zero? && head[k][:pass] > 0 }
  gone = base.keys - head.keys
  puts "| #{app} | #{base.size} | #{failing.(base)} | #{head.size} | #{failing.(head)} | #{regress.size} | #{fixed.size} |"
  details << "## #{app}\n\n" + (regress.empty? ? "No regressions.\n" : regress.map { "* #{_1}" }.join("\n") + "\n") +
    (gone.empty? ? "" : "\nOnly on r81 (#{gone.size}): #{gone.first(10).join("; ")}\n") +
    (fixed.empty? ? "" : "\nFixed on main: #{fixed.first(10).join("; ")}\n")
end
puts
puts details.join("\n")
