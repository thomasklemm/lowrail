# frozen_string_literal: true

require "pg"
require "json"
require "digest"

def snapshot(value)
  case value
  when String then [value.class.name, value.bytes, value.encoding.name, value.frozen?, value.valid_encoding?]
  when Array then [value.frozen?, value.map { snapshot(_1) }]
  else [value.class.name, value.to_s]
  end
end

connection = PG.connect(dbname: "pdrv")
observations = []
queries = [
  "SELECT x, ''::text AS empty, NULL::text AS missing, 'é中'::text AS text, decode('00ff','hex') AS blob, '-9223372036854775808'::bigint AS huge FROM generate_series(1,11) x",
  "SELECT NULL::integer, 0::integer, 9223372036854775807::bigint, -1::integer, 1.25::float8, '2024-02-29 13:17:31.123456'::timestamp",
  "SELECT ''::text, NULL::text, decode('','hex'), NULL::bytea WHERE false",
]
%w[UTF8 LATIN1 SQL_ASCII].each do |encoding|
  connection.set_client_encoding(encoding)
  [0, 1].each do |format|
    queries.each do |sql|
      ["strings", "oid", "column", "fallback", "ruby"].each do |mapping|
        result = connection.exec_params(sql, [], format)
        begin
          coders = result.nfields.times.map do |field|
            type = result.ftype(field)
            if format == 1
              { 20 => PG::BinaryDecoder::Integer, 23 => PG::BinaryDecoder::Integer,
                17 => PG::BinaryDecoder::Bytea, 25 => PG::BinaryDecoder::String }[type]&.new(oid: type, format: format)
            else
              { 20 => PG::TextDecoder::Integer, 23 => PG::TextDecoder::Integer,
                17 => PG::TextDecoder::Bytea, 25 => PG::TextDecoder::String }[type]&.new(oid: type)
            end
          end
          oid_map = PG::TypeMapByOid.new
          coders.compact.each { oid_map.add_coder(_1) }
          oid_map.max_rows_for_online_lookup = 20
          case mapping
          when "oid" then result.type_map = oid_map
          when "column" then result.type_map = PG::TypeMapByColumn.new(coders)
          when "fallback" then result.type_map = PG::TypeMapByColumn.new([nil] * result.nfields).with_default_type_map(oid_map)
          when "ruby"
            coder_class = Class.new(PG::SimpleDecoder) do
              def decode(value, row, field)
                GC.start
                GC.compact
                [value, row, field]
              end
            end
            result.type_map = PG::TypeMapByColumn.new(coders.map { coder_class.new(format: format) })
          end
          first = result.values
          second = result.values
          identities = first.zip(second).map { |a, b| a.zip(b).map { |x, y| x.equal?(y) } }
          observations << [encoding, format, mapping, snapshot(first), snapshot(second), identities,
            result.fields.zip(result.fields).map { |a, b| a.equal?(b) }]
        rescue StandardError => error
          observations << [encoding, format, mapping, error.class.name, error.message]
        ensure
          result.clear
        end
      end
    end
  end
end
connection.set_client_encoding("SQL_ASCII")
begin
  result = connection.exec_params("SELECT $1::text, NULL::text", ["\xff".b])
  observations << snapshot(result.values)
  result.clear
rescue StandardError => error
  observations << [error.class.name, error.message]
end
begin
  result.values
rescue StandardError => error
  observations << [error.class.name, error.message]
end
result = connection.exec("SELECT 'first'::text, 'second'::text, NULL::text")
decoder_class = Class.new(PG::SimpleDecoder)
decoder_class.define_method(:decode) do |value, _row, _field|
  result.clear
  value
end
result.type_map = PG::TypeMapByColumn.new([decoder_class.new] * 3)
begin
  observations << snapshot(result.values)
rescue StandardError => error
  observations << [error.class.name, error.message]
end
connection.finish
observations << 4.times.map do
  Thread.new do
    c = PG.connect(dbname: "pdrv")
    c.type_map_for_results = PG::BasicTypeMapForResults.new(c)
    values = 100.times.map { c.exec("SELECT NULL::int, ''::text, -17::bigint").values }
    c.finish
    values
  end
end.map(&:value)
json = JSON.generate(observations)
puts JSON.generate(cases: observations.length, sha256: Digest::SHA256.hexdigest(json), observations: observations)
