module SharedLayoutWrite
  def put(v) = (@shared2 = v)
end
ordinary = Object.new.extend(SharedLayoutWrite)
record = Struct.new(:payload).new(:sentinel).extend(SharedLayoutWrite)
[ordinary, record].each do |o|
  12.times { |i| o.instance_variable_set(:"@shared#{i}", i) }
end
raise unless RubyVM::Shape.of(ordinary).id == RubyVM::Shape.of(record).id
raise unless RubyVM::Shape.of(ordinary).layout == :extended_or_rdata
300.times { |i| ordinary.put(i) }
RubyVM::ZJIT.reset_stats! if RubyVM::ZJIT.enabled?
100.times { |i| raise unless record.put(i) == i }
if RubyVM::ZJIT.enabled?
  stats = RubyVM::ZJIT.stats
  warn "cross-layout generic writes: #{stats.fetch(:dynamic_setivar_count)}"
  warn "cross-layout JIT instructions: #{stats.fetch(:zjit_insn_count)}"
  raise unless stats.fetch(:dynamic_setivar_count) == 0 && stats.fetch(:zjit_insn_count) >= 200
end
record.freeze
error = begin; record.put(:wrong); rescue FrozenError => e; e.class; end
raise unless [record.instance_variable_get(:@shared2), record.payload, error] == [99, :sentinel, FrozenError]
puts 'equal full shape across T_OBJECT/T_STRUCT: stored=99, payload=sentinel, frozen=FrozenError'
