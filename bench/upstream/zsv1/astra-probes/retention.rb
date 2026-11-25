require 'weakref'
module RetainedWriter
  def write(v) = (@slot = v)
end
class RetainedOrdinary
end
def ephemeral_refs
  o = RetainedOrdinary.new.extend(RetainedWriter)
  def o.marker = :singleton
  3.times { |i| o.write(i) }
  WeakRef.new(o)
end
refs = 100.times.map { ephemeral_refs }
3.times { GC.start }
GC.verify_compaction_references(expand_heap: true, toward: :empty)
live = refs.count { |ref| ref.weakref_alive? }
raise "retained #{live} singleton objects" unless live == 0
puts "singleton weak refs alive: #{live}/100"
warn "compaction classes: #{GC.latest_compact_info.fetch(:moved).fetch(:T_CLASS, 0)}"
