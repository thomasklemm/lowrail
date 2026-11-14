# Whole-process ZJIT counters for lead3_repro.rb's shape (no reset), to count compiles and exits.
class Model
  def self.types = 1
end
MODELS = Array.new(4) { Class.new(Model) }

def read(models)
  i = 0
  while i < 100
    models[i % models.size].types
    i += 1
  end
end

100.times { read(MODELS.first(Integer(ENV.fetch("P", "2")))) }
1100.times { read(MODELS) }
s = RubyVM::ZJIT.stats
p s.slice(:compiled_iseq_count, :failed_iseq_count, :compiled_side_exit_count, :side_exit_count, :exit_polymorphic_send_miss,
  :send_fallback_send_polymorphic_fallback, :code_region_bytes, :zjit_alloc_bytes)
