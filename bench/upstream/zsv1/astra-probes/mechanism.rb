class Mechanism
  def initialize = (@a = 0)
  def writes(n)
    i = 0
    while i < n
      @a = i
      i += 1
    end
    @a
  end
end
o = Mechanism.new.extend(Module.new)
1000.times { raise unless o.writes(1000) == 999 }
GC.start
GC.disable
RubyVM::ZJIT.reset_stats!
raise unless o.writes(100_000) == 99_999
p RubyVM::ZJIT.stats.select { |k,v| k.to_s.match?(/dynamic_setivar|setivar_fallback|no_profile_setivar|compile_error_out_of_memory|zjit_insn_count|compiled_iseq_count/) }
