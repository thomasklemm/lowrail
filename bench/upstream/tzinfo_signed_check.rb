# encoding: UTF-8
# frozen_string_literal: true

require 'json'
require 'digest'
require 'tmpdir'
$LOAD_PATH.unshift(File.join(File.realpath(ENV.fetch('TZINFO_SOURCE')), 'lib'))
require 'tzinfo'
load ENV['BASELINE_READER'] if ENV['BASELINE_READER']

def tzif(times, format = 2)
  abbreviation = "Ω\0".b
  offsets = [0, 0, 0].pack('NCC') + abbreviation
  header = lambda do |version, count|
    ["TZif#{version}", 0, 0, 0, count, 1, abbreviation.bytesize].pack('a5 x15 N6')
  end
  if format == 1
    header.call("\0", times.size) + times.pack('N*') + "\0" * times.size + offsets
  else
    words = times.flat_map { |time| [(time % (2**64)) / (2**32), time % (2**32)] }
    header.call(format.to_s, 0) + offsets + header.call(format.to_s, times.size) +
      words.pack('N*') + "\0" * times.size + offsets + "\n\n"
  end
end

if $PROGRAM_NAME == __FILE__
  boundaries = [-(2**63), -(2**62) - 1, -(2**62), -(2**32) - 1, -(2**32), -(2**31) - 1, -1, 0,
    1, 2**31 - 1, 2**31, 2**32 - 1, 2**32, 2**62 - 1, 2**62, 2**63 - 1]
  random = Random.new(1729)
  times = (boundaries + Array.new(256) { random.rand(-(2**63)...2**63) }).uniq.sort
  times.each do |time|
    bytes = [(time % (2**64)) / (2**32), time % (2**32)].pack('NN')
    high, low = bytes.unpack('NN')
    unsigned = (high << 32) | low
    old = unsigned >= 0x8000000000000000 ? unsigned - 0x10000000000000000 : unsigned
    raise 'integer decoding differs' unless bytes.unpack('q>')[0] == time && old == time
  end

  reader_class = TZInfo::DataSources.const_get(:ZoneinfoReader)
  parser_class = TZInfo::DataSources.const_get(:PosixTimeZoneParser)
  deduper = TZInfo.const_get(:StringDeduper).new
  reader = reader_class.new(parser_class.new(deduper), deduper)
  result = Dir.mktmpdir('signed-zoneinfo-check-') do |directory|
    path = File.join(directory, 'zone').freeze
    snapshots = [2, 3].map do |format|
      bytes = tzif(times, format).freeze
      File.binwrite(path, bytes)
      first = reader.read(path)
      second = reader.read(path)
      raise 'wrong timestamps' unless first.map(&:timestamp_value) == times
      raise 'returned array aliases' if first.equal?(second) || first.first.equal?(second.first)
      first.pop
      raise 'mutation affected independent read' unless second.size == times.size
      raise 'input changed' unless File.binread(path) == bytes
      raise 'Unicode abbreviation lost' unless second.first.offset.abbreviation == 'Ω'
      [format, second.map { |t| [t.timestamp_value, t.offset.base_utc_offset, t.offset.abbreviation] }]
    end
    subclass = Class.new(reader_class)
    raise 'reader subclass differs' unless subclass.new(parser_class.new(deduper), deduper).read(path).map(&:timestamp_value) == times
    raise 'path subclass differs' unless reader.read(Class.new(String).new(path).freeze).map(&:timestamp_value) == times
    raise 'frozen reader differs' unless reader.freeze.read(path).map(&:timestamp_value) == times
    zones = %w[Europe/London America/New_York Australia/Melbourne].map do |zone|
      values = reader.read(File.join(ENV.fetch('TZINFO_SOURCE'), 'test/zoneinfo', zone)).map do |t|
        [t.timestamp_value, t.offset.base_utc_offset, t.offset.std_offset, t.offset.abbreviation]
      end
      [zone, values.size, Digest::SHA256.hexdigest(JSON.generate(values))]
    end
    malformed = [tzif([19, 7]), tzif([7])[0, 95], 'not a TZif file']
    errors = malformed.map do |bytes|
      File.binwrite(path, bytes)
      begin
        reader.read(path)
        raise 'malformed TZif accepted'
      rescue TZInfo::DataSources::InvalidZoneinfoFile => error
        [error.class.name, error.message.gsub(path, '<fixture>')]
      end
    end
    {values: times.size, snapshots: snapshots, zones: zones, errors: errors,
      independent_ownership: true, frozen_path_and_reader: true, reader_and_path_subclass: true}
  end
  puts JSON.generate(result)
  warn "PASS: #{times.size} signed values, TZif v2/v3, ownership, frozen/subclass inputs, three zones and malformed files; #{RUBY_DESCRIPTION}"
end
