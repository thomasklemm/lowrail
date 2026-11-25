# frozen_string_literal: true

# What the profiler and the lowering runtime share from lib/lowrail.rb,
# without the runtime: requiring this loads nothing else.
module Lowrail
  CONST_DEFINED = Module.instance_method(:const_defined?)
  AUTOLOAD = Module.instance_method(:autoload?)
  CONST_GET = Module.instance_method(:const_get)
  CONST_PREFIX = String.instance_method(:delete_prefix)
  CONST_PARTS = String.instance_method(:split)
  CONST_EACH = Array.instance_method(:each)
  private_constant :CONST_DEFINED, :AUTOLOAD, :CONST_GET, :CONST_PREFIX, :CONST_PARTS, :CONST_EACH

  class << self
    # Runtime facts observe constants; they never resolve an autoload or
    # invoke const_missing. A missing dependency means wait or fall back.
    def loaded_constant(name)
      owner = Object
      CONST_EACH.bind_call(CONST_PARTS.bind_call(CONST_PREFIX.bind_call(name, "::"), "::")) do |part|
        return unless Module === owner && CONST_DEFINED.bind_call(owner, part, false) &&
          !AUTOLOAD.bind_call(owner, part, false)
        owner = CONST_GET.bind_call(owner, part, false)
      end
      owner
    end

    def debug(msg)
      warn "[lowrail] #{msg}" if ENV["LOWRAIL_DEBUG"]
    end
  end
end
