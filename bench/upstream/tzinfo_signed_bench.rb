# frozen_string_literal: true

# Standalone public allocation benchmark; no app, Lowrail or tzdata needed.
# Ruby 4.0.7 used. Save this file anywhere, then:
#
#   gem install concurrent-ruby -v 1.3.8 --no-document
#   git clone https://github.com/tzinfo/tzinfo.git tzinfo-signed
#   git -C tzinfo-signed fetch https://github.com/thomasklemm/tzinfo.git thomasklemm/signed-zoneinfo-transitions
#   git -C tzinfo-signed worktree add --detach ../tzinfo-signed-off fdab2521b1319d88445e22c9e34aa40794f3b917
#   git -C tzinfo-signed worktree add --detach ../tzinfo-signed-on 57c9c3ad35c3fa08bb4d0310cf3f0e52ae01f961
#   TZINFO_SOURCE="$PWD/tzinfo-signed-off" ruby tzinfo_signed_bench.rb > off.json
#   TZINFO_SOURCE="$PWD/tzinfo-signed-on" ruby tzinfo_signed_bench.rb > on.json
# Repeat both invocations with ruby --yjit (and --zjit on a supporting build).
# Negative32: 288 -> 160 objects/read; boundaries: 72 -> 60. Positive32,
# format1 and empty controls stay unchanged. The entire reader, including IO,
# is counted; synthetic fixture creation and explicit GC are outside windows.
# This makes no latency/throughput/Ir claim and needs no private corpus data.

require "json"
require "digest"
require "tmpdir"
gem "concurrent-ruby", "1.3.8"
source = File.realpath(ENV.fetch("TZINFO_SOURCE"))
sha = Digest::SHA256.file(File.join(source, "lib/tzinfo/data_sources/zoneinfo_reader.rb")).hexdigest
raise "expected pinned TZInfo baseline or fork source" unless %w[
  a818fbbf1085edb82db7687546dfc853602be803e1901a84a3c9765d225a1f30
  665dc7295335d8cb84c7445891b314c45a6a0466a3f2b88d5c9f6f53b9474589
].include?(sha)
$LOAD_PATH.unshift(File.join(source, "lib"))
require "tzinfo"

def fixture(times, format)
  abbreviation = "Ω\0".b
  offsets = [0, 0, 0].pack("NCC") + abbreviation
  header = ->(version, count) { ["TZif#{version}", 0, 0, 0, count, 1, abbreviation.bytesize].pack("a5 x15 N6") }
  if format == 1
    header.call("\0", times.size) + times.pack("N*") + "\0" * times.size + offsets
  else
    words = times.flat_map { |time| [(time % (2**64)) / (2**32), time % (2**32)] }
    header.call(format.to_s, 0) + offsets + header.call(format.to_s, times.size) +
      words.pack("N*") + "\0" * times.size + offsets + "\n\n"
  end
end

def read_all(reader, path, count)
  count.times { reader.read(path) }
end

deduper = TZInfo.const_get(:StringDeduper).new
parser = TZInfo::DataSources.const_get(:PosixTimeZoneParser).new(deduper)
reader = TZInfo::DataSources.const_get(:ZoneinfoReader).new(parser, deduper)
cases = {
  "format1_control" => [[-19, 7, 151], 1],
  "positive_32" => [Array.new(32) { 7 + _1 * 1000 }, 2],
  "negative_32" => [Array.new(32) { -4_000_000_000 + _1 * 1000 }, 2],
  "signed_boundaries" => [[-(2**63), -(2**62) - 1, -19, 7, 2**62, 2**63 - 1], 3],
  "empty_control" => [[], 2]
}
measurements = Dir.mktmpdir("public-zoneinfo-bench-") do |directory|
  path = File.join(directory, "zone")
  cases.map do |label, (times, format)|
    File.binwrite(path, fixture(times, format))
    value = reader.read(path)
    if times.empty?
      raise "wrong constant offset" unless value.is_a?(TZInfo::TimezoneOffset) && value.base_utc_offset == 0 && value.abbreviation == "Ω"
    else
      raise "wrong timestamps" unless value.map(&:timestamp_value) == times
    end
    read_all(reader, path, 3000)
    GC.start
    before = GC.stat(:total_allocated_objects)
    read_all(reader, path, 2000)
    objects = (GC.stat(:total_allocated_objects) - before).fdiv(2000)
    { case: label, operations: 2000, objects_per_read: objects }
  end
end
puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, tzinfo: TZInfo::VERSION, source_sha256: sha,
  yjit: RubyVM::YJIT.enabled?, zjit: !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?),
  scope: "allocations only; whole TZif read; synthetic public fixtures", measurements: measurements)
