# ruby --zjit --zjit-stats-quiet lead3_repro.rb   (or --yjit --yjit-stats=quiet)
class Model
  def self.types = 1
end
MODELS = Array.new(4) { Class.new(Model) }

def read(models)
  i = 0
  while i < 100
    models[i % models.size].types # one call site, every receiver resolves Model.types
    i += 1
  end
end

100.times { read(MODELS.first(2)) } # compiled while the site has seen 2 of the 4 classes
100.times { read(MODELS) }          # warm with all 4

if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
  RubyVM::ZJIT.reset_stats!
  1000.times { read(MODELS) }
  s = RubyVM::ZJIT.stats
  p s.slice(:dynamic_send_count, :send_fallback_send_polymorphic_fallback).transform_values { _1 / 100_000.0 }
else
  RubyVM::YJIT.reset_stats!
  1000.times { read(MODELS) }
  s = RubyVM::YJIT.runtime_stats
  p s.slice(:num_send_dynamic, :send_megamorphic).transform_values { _1 / 100_000.0 }
end
