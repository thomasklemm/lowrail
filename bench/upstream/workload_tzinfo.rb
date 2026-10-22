# frozen_string_literal: true

# TZif reader controls and whole-read allocation/regression worker.
require "json"
require "digest"
require "tmpdir"
source = File.realpath(ENV.fetch("TZINFO_SOURCE"))
$LOAD_PATH.unshift(File.join(source, "lib"))
require "tzinfo"

def tzif(times, format = 2, abbreviation = "Ω")
  # Build bytes independently from the decoder, including signed boundaries.
  abbreviation = abbreviation.b + "\0"
  offsets = [0, 0, 0].pack("NCC") + abbreviation
  header = ->(version, n) { ["TZif#{version}", 0, 0, 0, n, 1, abbreviation.bytesize].pack("a5 x15 N6") }
  if format == 1
    header.call("\0", times.size) + times.pack("N*") + "\0" * times.size + offsets
  else
    words = times.flat_map { |time| [(time % (2**64)) / (2**32), time % (2**32)] }
    header.call(format.to_s, 0) + offsets + header.call(format.to_s, times.size) + words.pack("N*") + "\0" * times.size + offsets + "\n\n"
  end
end

def jit_stats
  if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    RubyVM::ZJIT.stats
  elsif RubyVM::YJIT.enabled?
    RubyVM::YJIT.runtime_stats
  else
    {}
  end
end

def read_batch(reader, path, count)
  count.times { reader.read(path) }
end

command, output = ARGV
raise "fresh output required" if File.exist?(output)
reader_class = TZInfo::DataSources.const_get(:ZoneinfoReader)
parser_class = TZInfo::DataSources.const_get(:PosixTimeZoneParser)
deduper = TZInfo.const_get(:StringDeduper).new
reader = reader_class.new(parser_class.new(deduper), deduper)
Dir.mktmpdir("u3-zoneinfo-") do |directory|
  path = File.join(directory, "zone")
  if command == "controls"
    boundaries = [-(2**63), -(2**62) - 1, -(2**62), -(2**32) - 1, -(2**32), -(2**31) - 1, -1, 0,
      1, 2**31 - 1, 2**31, 2**32 - 1, 2**32, 2**62 - 1, 2**62, 2**63 - 1]
    random = Random.new(1729)
    times = (boundaries + Array.new(256) { random.rand(-(2**63)...2**63) }).uniq.sort
    snapshots = [2, 3].map do |format|
      bytes = tzif(times, format).freeze
      File.binwrite(path, bytes)
      first = reader.read(path.freeze)
      second = reader.read(path)
      raise "wrong timestamps" unless first.map(&:timestamp_value) == times
      raise "returned array aliases" if first.equal?(second) || first.first.equal?(second.first)
      first.pop
      raise "mutation affected independent read" unless second.size == times.size
      raise "input changed" unless File.binread(path) == bytes
      raise "Unicode abbreviation lost" unless second.first.offset.abbreviation == "Ω"
      [format, second.map { [_1.timestamp_value, _1.offset.base_utc_offset, _1.offset.abbreviation] }]
    end
    subclass = Class.new(reader_class)
    raise "subclass changed" unless subclass.new(parser_class.new(deduper), deduper).read(path).map(&:timestamp_value) == times
    path_subclass = Class.new(String).new(path).freeze
    raise "String subclass changed" unless reader.read(path_subclass).map(&:timestamp_value) == times
    raise "frozen reader changed" unless reader.freeze.read(path).map(&:timestamp_value) == times
    system_zones = %w[Europe/Tallinn America/New_York Africa/Monrovia].to_h do |zone|
      values = reader.read("/usr/share/zoneinfo/#{zone}").map do |transition|
        [transition.timestamp_value, transition.offset.base_utc_offset, transition.offset.std_offset, transition.offset.abbreviation]
      end
      [zone, { count: values.size, sha256: Digest::SHA256.hexdigest(JSON.generate(values)) }]
    end
    bad = tzif([19, 7])
    File.binwrite(path, bad)
    errors = []
    [bad, tzif([7])[0, 95], "not a TZif file"].each do |bytes|
      File.binwrite(path, bytes)
      begin
        reader.read(path)
        raise "malformed TZif accepted"
      rescue TZInfo::DataSources::InvalidZoneinfoFile => error
        errors << [error.class.name, error.message.gsub(path, "<fixture>")]
      end
    end
    result = { snapshots: snapshots, independent_ownership: true, frozen_input_and_reader: true,
      reader_and_path_subclass: true, system_zones: system_zones, errors: errors }
  elsif command == "measure"
    cases = {
      "format1_control" => [[-19, 7, 151], 1],
      "positive_32" => [Array.new(32) { 7 + _1 * 1000 }, 2],
      "negative_32" => [Array.new(32) { -4_000_000_000 + _1 * 1000 }, 2],
      "signed_boundaries" => [[-(2**63), -(2**62) - 1, -19, 7, 2**62, 2**63 - 1], 3],
      "empty_control" => [[], 2]
    }
    measurements = cases.map do |label, (times, format)|
      File.binwrite(path, tzif(times, format))
      read_batch(reader, path, 3000)
      GC.start
      before = GC.stat(:total_allocated_objects)
      read_batch(reader, path, 2000)
      objects = (GC.stat(:total_allocated_objects) - before).fdiv(2000)
      GC.start
      jit_before = jit_stats
      start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
      read_batch(reader, path, 10000)
      elapsed = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - start
      jit_after = jit_stats
      deltas = jit_after.filter_map { |key, value| [key, value - jit_before.fetch(key, 0)] if value.is_a?(Numeric) && value != jit_before.fetch(key, 0) }.to_h
      { case: label, objects: objects, seconds_per_operation: elapsed / 10000, jit_deltas: deltas }
    end
    result = { ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, zjit: defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?,
      tzinfo: TZInfo::VERSION, source_sha256: Digest::SHA256.file(File.join(source, "lib/tzinfo/data_sources/zoneinfo_reader.rb")).hexdigest,
      measurements: measurements }
  else
    abort "usage: workload_tzinfo.rb controls|measure NEW_JSON (TZINFO_SOURCE required)"
  end
  File.write(output, JSON.pretty_generate(result) + "\n")
  puts JSON.generate(result)
end
