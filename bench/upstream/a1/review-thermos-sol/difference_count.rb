module UpstreamBench
  CASES = {}
  def self.report(name, &block) = CASES[name] = block
end
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
load File.join(ENV.fetch("LOWRAIL_ROOT"), "bench/upstream/a1/a1_body.rb")
$differences = Hash.new(0)
module CountDifferences
  def -(other)
    loc = caller_locations(1, 1).first
    $differences[[File.basename(loc.path), loc.lineno, loc.label]] += 1
    super
  end
end
ActiveRecord::Relation::WhereClause.prepend(CountDifferences)
UpstreamBench::CASES.each do |name, call|
  2.times { call.call }
  $differences.clear
  call.call
  puts "#{name}: #{$differences.sort.to_h.inspect}"
end
