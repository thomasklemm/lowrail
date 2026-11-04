# Ruby master: a non-main Ractor reading a class ivar that holds a frozen Set
# aborts with [BUG] rb_objspace_reachable_objects_from_local. Bug #22419 (open,
# fix in ruby/ruby#19283). Action Pack's action_methods and Mime::Type hit it.
class C
  @s = Set[1, 2].freeze
  class << self; attr_reader :s; end
end
p Ractor.new { C.s.include?(1) }.value
