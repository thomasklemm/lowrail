# frozen_string_literal: true

# Astra's two blocking repros for HM4: a subclass with warnings disabled built in a non-main Ractor, and a class
# whose disabled_warnings reader is overridden. Usage: ruby -W0 -I HASHIE/lib quiet_ractor_and_reader.rb
require 'hashie'
require 'logger'
require 'stringio'

log = StringIO.new
Hashie.logger = Logger.new(log)

class Quiet < Hashie::Mash
  disable_warnings
end

class Selective < Hashie::Mash
  def self.disabled_warnings = [:size]
end

ractor = Ractor.new { Quiet.new(fresh: 3).to_hash }
result = begin
  ractor.respond_to?(:value) ? ractor.value : ractor.take
rescue StandardError => e
  "#{e.class}: #{(e.cause || e).class}"
end
puts "quiet subclass in a Ractor: #{result.inspect}"

asked = Selective.disable_warnings?(:size)
Selective.new(size: 7)
puts "overridden disabled_warnings reader: disable_warnings?(:size) #{asked}, warnings logged #{log.string.scan('WARN').size}"
