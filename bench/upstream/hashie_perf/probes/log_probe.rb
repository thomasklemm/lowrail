# Compares what each logger receives from Mash's conflict warning: base, block form (A), level check (B).
require 'hashie'; require 'logger'; require 'stringio'
begin; require 'active_support'; require 'active_support/logger'; require 'active_support/broadcast_logger'; require 'active_support/tagged_logging'; rescue LoadError; end
ROUTE = ARGV[0]
if ROUTE != 'base'
  Hashie::Mash.class_eval do
    private
    define_method(:_log_built_in_message) do |method_key|
      return if self.class.disable_warnings?(method_key)
      build = -> { "You are setting a key that conflicts with a built-in method #{self.class}##{method_key} #{Hashie::Utils.method_information(method(method_key))}. This can cause unexpected behavior when accessing the key as a property. You can still access the key via the #[] method." }
      if ROUTE == 'block'
        Hashie.logger.warn { build.() }
      else
        l = Hashie.logger
        return if l.respond_to?(:warn?) && !l.warn?
        l.warn(build.())
      end
    end
  end
end
rec = Class.new { attr_reader :got; def initialize = @got = []; def warn(msg) = @got << msg }
recsplat = Class.new { attr_reader :got; def initialize = @got = []; def warn(*a, &b) = @got << [a, b && :block] }
recq = Class.new { attr_reader :got; def initialize = @got = []; def warn?(*) = false; def warn(*a) = @got << a }
sio = -> { StringIO.new }
loggers = {
  'Logger DEBUG' => -> { io = sio.(); [Logger.new(io), -> { io.string.gsub(/\[.*?\]/, '') }] },
  'Logger ERROR' => -> { io = sio.(); l = Logger.new(io); l.level = :error; [l, -> { io.string }] },
  'Logger progname' => -> { io = sio.(); l = Logger.new(io, progname: 'app'); l.formatter = proc { |s, _, p, m| "#{s}|#{p}|#{m}\n" }; [l, -> { io.string }] },
  'Logger nil' => -> { [Logger.new(nil), -> { '' }] },
  'warn(msg) only' => -> { r = rec.new; [r, -> { r.got }] },
  'warn(*args)' => -> { r = recsplat.new; [r, -> { r.got }] },
  'warn? false but warn writes' => -> { r = recq.new; [r, -> { r.got }] },
}
if defined?(ActiveSupport::Logger)
  loggers['ActiveSupport::Logger'] = -> { io = sio.(); [ActiveSupport::Logger.new(io), -> { io.string }] }
  loggers['BroadcastLogger x2'] = -> { a = sio.(); b = sio.(); [ActiveSupport::BroadcastLogger.new(ActiveSupport::Logger.new(a), ActiveSupport::Logger.new(b)), -> { [a.string, b.string] }] }
  loggers['TaggedLogging'] = -> { io = sio.(); l = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(io)); [l, -> { io.string }] }
end
loggers.each do |name, make|
  logger, out = make.()
  Hashie.logger = logger
  r = begin; Hashie::Mash.new('key' => 1, 'zip' => 2); :ok; rescue Exception => e; "#{e.class}: #{e.message[0, 60]}"; end
  puts "#{name} | #{r} | #{out.().inspect[0, 400]}"
end
