# frozen_string_literal: true

# Differential probe for Slack::Messages::Message calling disable_warnings instead of overriding Hashie's private
# log_built_in_message: bundle exec ruby -I SLACK/lib message_diff.rb > out; diff two trees' outputs per hashie version.
# Each row has the result, the message afterwards and the number of Hashie warnings logged; "class" rows record
# reflection, which is expected to differ.
require 'slack-ruby-client'
require 'json'
require 'logger'
require 'stringio'

LOG = StringIO.new
Hashie.logger = Logger.new(LOG)

def show(value)
  case value
  when Hash then "#{value.class.name || 'anon'}{#{value.map { |k, v| "#{k.inspect}=>#{show(v)}" }.join(',')}}"
  when Array then "[#{value.map { |v| show(v) }.join(',')}]"
  else value.inspect
  end
end

def warnings
  count = LOG.string.scan('conflicts with a built-in method').size
  LOG.truncate(0)
  LOG.rewind
  count
end

message = Slack::Messages::Message
klasses = {
  'Message' => message,
  'subclass' => Class.new(message),
  'subclass with own method' => Class.new(message) { def channel = :own }
}
# disable_warnings takes method names from Hashie 4.0.0 on.
unless Hashie::Mash.method(:disable_warnings).arity.zero?
  klasses['subclass disable_warnings(:zip)'] = Class.new(message) { disable_warnings(:zip) }
end
klasses['quiet(:zip)'] = message.quiet(:zip) if message.respond_to?(:quiet)
keys = ['size', :size, 'key', 'zip', 'min', 'count', 'default', 'class', 'channel', 'ok', 'to_s', 'size=', 'ok?', '', 1, nil]
seeds = [{}, { 'ok' => true, 'file' => { 'size' => 1, 'name' => 'a' } },
         { 'messages' => [{ 'count' => 2, 'files' => [{ 'size' => 3, 'zip' => 4 }] }], size: 5 }]
operations = {
  'new' => ->(m, k) { m.class.new(k => { 'size' => 1, 'items' => [{ 'count' => 2 }] }) },
  '[]=' => ->(m, k) { m[k] = 1 },
  'setter' => ->(m, k) { m.public_send(:"#{k}=", 1) },
  'merge' => ->(m, k) { m.merge(k => [{ 'zip' => 1 }]) },
  'update' => ->(m, k) { m.update(k => { 'size' => 1 }) },
  'dup' => ->(m, k) { (m[k] = 3; m.dup) },
  'read' => ->(m, k) { [m[k], m.respond_to?(k.to_s), (m.public_send(k) if k.is_a?(String) && k =~ /\A[a-z_]+\z/)] },
  'to_s' => ->(m, k) { (m[k] = 2; m.to_s) },
  'to_hash' => ->(m, k) { (m[k] = 2; m.to_hash) },
  'to_json' => ->(m, k) { (m[k] = 2; JSON.generate(m)) }
}

klasses.each do |label, klass|
  seeds.each_with_index do |seed, si|
    keys.each do |key|
      operations.each do |op, run|
        [false, true].each do |frozen|
          warnings
          row = begin
            mash = klass.new(seed)
            built = warnings
            mash.freeze if frozen
            result = run.call(mash, key)
            [show(result), result.class.name, show(mash), "warnings #{built}+#{warnings}"]
          rescue Exception => e # rubocop:disable Lint/RescueException
            ["#{e.class}: #{e.message.gsub(/0x\h+/, 'X')[0, 120]}", "warnings #{warnings}"]
          end
          puts [label, si, key.inspect, op, frozen, *row].join(' | ').gsub(/#<Class:0x\h+>/, 'anon')
        end
      end
    end
  end
  puts "class #{label} | disable_warnings? #{klass.respond_to?(:disable_warnings?) && [nil, :size, :zip].map { |k| klass.method(:disable_warnings?).arity.zero? ? klass.disable_warnings? : klass.disable_warnings?(k) }.inspect} | " \
       "own private methods #{klass.private_instance_methods(false).sort.inspect} | ancestors #{klass.ancestors.take_while { |a| a != Hashie::Mash }.size}"
end

if defined?(Ractor)
  ractor = Ractor.new { Slack::Messages::Message.new('ok' => true, 'file' => { 'name' => 'a' }).to_hash }
  result = begin
    ractor.respond_to?(:value) ? ractor.value : ractor.take
  rescue StandardError => e
    "#{e.class}: #{(e.cause || e).class}"
  end
  puts "ractor, no conflicting key | #{result.inspect}"
  ractor = Ractor.new { Slack::Messages::Message.new('file' => { 'size' => 1 }).to_hash }
  result = begin
    ractor.respond_to?(:value) ? ractor.value : ractor.take
  rescue StandardError => e
    "#{e.class}: #{(e.cause || e).class}"
  end
  puts "ractor, conflicting key | #{result.inspect}"
end

late = Class.new(Slack::Messages::Message) do
  private

  def log_built_in_message(*) = super
end
warnings
result = begin
  late.new('size' => 1)
  "ok, warnings #{warnings}"
rescue StandardError => e
  "#{e.class}"
end
puts "class subclass whose log_built_in_message calls super | #{result}"
