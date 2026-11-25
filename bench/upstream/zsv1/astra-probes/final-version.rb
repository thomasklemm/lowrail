class FinalWrite
  def write(v, x)
    @a = v
    x + 1
  end
end
o = FinalWrite.new.extend(Module.new)
100.times { |i| raise unless o.write(i, 1) == 2 }
100.times { |i| raise unless o.write(i, 1.5) == 2.5 }

if RubyVM::ZJIT.enabled?
  RubyVM::ZJIT.reset_stats!
end
100.times { |i| raise unless o.write(i, 1.5) == 2.5 }
if RubyVM::ZJIT.enabled?
  stats = RubyVM::ZJIT.stats
  warn "matched dynamic writes: #{stats.fetch(:dynamic_setivar_count)}"
  raise unless stats.fetch(:dynamic_setivar_count) == 0
end

o.instance_variable_set(:@unseen_astra_shape, :marker)
RubyVM::ZJIT.reset_stats! if RubyVM::ZJIT.enabled?
100.times { |i| raise unless o.write(i, 1.5) == 2.5 }
if RubyVM::ZJIT.enabled?
  stats = RubyVM::ZJIT.stats
  warn "unmatched dynamic writes: #{stats.fetch(:dynamic_setivar_count)}"
  warn "no_side_exits fallbacks: #{stats.fetch(:setivar_fallback_no_side_exits)}"
  raise unless stats.fetch(:dynamic_setivar_count) == 100
  raise unless stats.fetch(:setivar_fallback_no_side_exits) == 100
end
o.freeze
error = begin; o.write(:wrong, 1.5); rescue FrozenError => e; e.class; end
raise unless [error, o.instance_variable_get(:@a)] == [FrozenError, 99]
puts 'final-version results: matched=2.5, unmatched=2.5, frozen=FrozenError, stored=99'
