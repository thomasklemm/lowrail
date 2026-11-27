# frozen_string_literal: true

require "json"
require "rubygems/package"
require "zlib"

root = File.expand_path("../../../../../..", __dir__)
%w[L6-2026-11-27 L6-w102-2026-11-27 L6-master-zjit-2026-11-27
  L6-master-zjit-serializable-hash-2026-11-27].each do |run|
  path = File.join(root, "bench/upstream/lead6/body", run)
  data = JSON.parse(File.read(File.join(path, "results.json")))
  raise "wrong base" unless data.dig("sides", "base", "head") == "088fc0cf61e4ba0c7987decafacc69adb3e22eec"
  raise "wrong head" unless data.dig("sides", "candidate", "head") == "8b1c6428ea056b3c5983372d85b85615ae3d3f45"
  totals = {}
  Zlib::GzipReader.open(File.join(path, "raw/callgrind.tar.gz")) do |gzip|
    Gem::Package::TarReader.new(gzip) do |tar|
      tar.each do |entry|
        totals[entry.full_name] = Integer(entry.read.scan(/^totals: (\d+)/).last.fetch(0)) if entry.file?
      end
    end
  end
  puts run
  indexes = Hash.new(0)
  data.fetch("instructions").each do |cell, values|
    mode, name = cell.split(" ", 2)
    indexes[mode] += 1
    stem = "ir-#{mode}-#{indexes[mode]}-#{name.gsub(/\W+/, '_')}"
    { "base" => "base1", "candidate" => "candidate", "base2" => "base2" }.each do |side, field|
      observed = (totals.fetch("#{stem}-#{side}-n#{data.fetch('n')}.callgrind") -
        totals.fetch("#{stem}-#{side}-n0.callgrind")) / data.fetch("n").to_f
      raise "mismatch #{cell} #{side}" unless (observed - values.fetch(field)).abs < 0.000001
    end
    puts "  #{cell}: verified #{values.values_at('base1', 'candidate', 'base2').inspect}; " \
      "delta=#{(100 * values.fetch('change')).round(4)}%; A/A=#{(100 * values.fetch('aa')).round(4)}%; " \
      "claim=#{values.fetch('claim')}; JIT-flat=#{values.dig('jit', 'flat').inspect}"
  end
  data.fetch("objects").each do |cell, values|
    puts "  objects #{cell}: #{values.values_at('base1', 'candidate', 'base2').inspect}"
  end
end
puts "ALL_ARCHIVED_TOTALS_MATCH"
