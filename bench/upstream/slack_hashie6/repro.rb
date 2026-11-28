# frozen_string_literal: true
require 'slack-ruby-client'
require 'logger'
require 'stringio'
LOG = StringIO.new
Hashie.logger = Logger.new(LOG)
def count
  n = LOG.string.scan('conflicts with a built-in method').size
  LOG.truncate(0); LOG.rewind
  n
end
def try
  count
  r = yield
  "#{r.inspect} warnings #{count}"
rescue Exception => e
  "#{e.class}: #{(e.cause || e).class} #{(e.cause || e).message[0, 60]}"
end
m = Slack::Messages::Message
puts "plain size | #{try { m.new('size' => 7).to_hash }}"
puts "nested size | #{try { m.new('file' => { 'size' => 1 }).to_hash }}"
puts "frozen subclass size | #{try { Class.new(m).freeze.new('size' => 7).to_hash }}"
if m.method(:disable_warnings).arity != 0
  puts "subclass zip | #{try { Class.new(m) { disable_warnings(:zip) }.new('size' => 7).to_hash }}"
  puts "quiet zip | #{try { m.quiet(:zip).new('size' => 7).to_hash }}" if m.respond_to?(:quiet)
  raising = Object.new
  def raising.warn(*) = raise(IOError, 'logger failed')
  old = Hashie.logger
  Hashie.logger = raising
  puts "subclass zip, raising logger | #{try { Class.new(m) { disable_warnings(:zip) }.new('size' => 7).to_hash }}"
  puts "plain, raising logger | #{try { m.new('size' => 7).to_hash }}"
  Hashie.logger = old
end
if defined?(Ractor)
  r = Ractor.new { Slack::Messages::Message.new('size' => 7).to_hash }
  puts "ractor size | #{try { r.respond_to?(:value) ? r.value : r.take }}"
  r = Ractor.new { Slack::Messages::Message.new('ok' => true).to_hash }
  puts "ractor ok | #{try { r.respond_to?(:value) ? r.value : r.take }}"
  r = Ractor.new { Class.new(Slack::Messages::Message).new('size' => 17).to_hash }
  puts "ractor, subclass defined in it | #{try { r.respond_to?(:value) ? r.value : r.take }}"
end
