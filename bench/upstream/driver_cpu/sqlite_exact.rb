# frozen_string_literal: true

require "sqlite3"
require "json"
require "digest"

def snapshot(value)
  case value
  when String then [value.class.name, value.bytes, value.encoding.name, value.frozen?, value.valid_encoding?]
  when Array then [value.frozen?, value.map { snapshot(_1) }]
  else [value.class.name, value.to_s]
  end
end

class BoundString < String
  def encode(*) = raise("unexpected Ruby encode")
  def to_str = raise("unexpected to_str")
end

values = [nil, "", "plain", "é中", "a\0b", "\xff".b, SQLite3::Blob.new("\0\xff"),
  0, -1, 2**62 - 1, -(2**63), 2**63 - 1, 2**63, 2**100, -2**100, 1.25]
%w[UTF-8 US-ASCII UTF-16LE UTF-16BE ISO-8859-1 EUC-JP].each do |encoding|
  ["", "ascii", "\xff".b, "\xc3\xa9".b, "\0\xff\0".b].each do |bytes|
    string = bytes.dup.force_encoding(encoding)
    values.concat([string, string.dup.freeze, BoundString.new(string)])
  end
end

observations = []
[nil, Encoding::UTF_8, Encoding::ISO_8859_1].each do |internal|
  Encoding.default_internal = internal
  %w[UTF-8 UTF-16le].each do |database_encoding|
    db = SQLite3::Database.new(":memory:")
    db.execute("PRAGMA encoding='#{database_encoding}'")
    stmt = db.prepare("SELECT ?, typeof(?)")
    values.each do |input|
      before = snapshot(input)
      begin
        stmt.reset!
        stmt.bind_param(1, input)
        stmt.bind_param(2, input)
        GC.start
        GC.verify_compaction_references(double_heap: true, toward: :empty) if ENV["COMPACT"]
        result = stmt.to_a
        observations << [before, snapshot(result), snapshot(input), result[0][0].equal?(input)]
      rescue StandardError => error
        observations << [before, error.class.name, error.message, snapshot(input)]
      end
    end
    stmt.close
    db.close
  end
end
Encoding.default_internal = nil
db = SQLite3::Database.new(":memory:")
[1, 2, 3, 4, 7, 8, 16, 32, 127, 128, 129, 1000, 2000].each do |width|
  inputs = width.times.map do |i|
    [nil, "", "cell-é-#{i}", "\xff".b.force_encoding("UTF-8"), SQLite3::Blob.new("\0\xff#{i}"),
      -(2**63), 2**100, "long-#{i}" * 1000][i % 8]
  end
  stmt = db.prepare("SELECT #{width.times.map { "?" }.join(',')}")
  stmt.bind_params(inputs)
  first = stmt.to_a
  GC.verify_compaction_references(double_heap: true, toward: :empty) if ENV["COMPACT"]
  stmt.reset!
  second = stmt.to_a
  observations << [width, snapshot(first), snapshot(second), first[0].zip(second[0]).map { |a, b| a.equal?(b) },
    stmt.columns.equal?(stmt.columns), stmt.columns.map(&:frozen?)]
  stmt.close
end
stmt = db.prepare("SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?")
stmt.bind_params(*9.times.map { "stress-é-#{_1}" })
begin
  GC.stress = true
  stressed = stmt.to_a
ensure
  GC.stress = false
end
observations << snapshot(stressed)
stmt.close
db.close
threads = 4.times.map do |index|
  Thread.new(index) do |thread_index|
    connection = SQLite3::Database.new(":memory:")
    output = 100.times.map do |i|
      connection.get_first_row("SELECT ?, ?, ?", ["thread-é-#{thread_index}-#{i}", i * -100_003 - thread_index, nil])
    end
    connection.close
    output
  end
end
observations << threads.map(&:value)
json = JSON.generate(observations)
puts JSON.generate(cases: observations.length, sha256: Digest::SHA256.hexdigest(json), observations: observations)
