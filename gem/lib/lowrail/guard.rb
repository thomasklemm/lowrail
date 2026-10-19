# frozen_string_literal: true

module Lowrail
  # Validates the boot facts a unit assumed and resets units when a method
  # they depend on may have changed. Resetting sets the state back to nil, so
  # the next call revalidates: a stubbed method falls back to the original
  # body, and the fast path returns once the stub is removed.
  #
  # A method fact {receiver, method, singleton, owner, source_location,
  # visibility} holds when
  #   * Receiver#method (or Receiver.method for singleton facts) resolves to a
  #     method with that owner, source location and visibility. A method that
  #     is a copy (alias) of that same definition also counts: Minitest's stub
  #     leaves `alias_method name, saved` behind in the singleton class after
  #     the block, which must not disable the unit forever.
  #   * no subclass of Receiver resolves the name differently (instance facts
  #     on classes), because lowered code in Receiver may run with self being
  #     a subclass instance;
  #   * no live object that is_a?(Receiver) carries a singleton override of the
  #     name (instance stubs, `def obj.name`, `obj.extend(M)`), tracked weakly.
  #
  # Hooks (method_added & co. on Module, singleton_method_added & co. on
  # BasicObject) reset only units whose facts mention an affected name.
  #
  # Known holes (not detected; `lowrail verify` is the backstop):
  #   * a class defining `self.method_added` (or singleton_method_added) that
  #     does not call super;
  #   * visibility changes of a method in its own class (`private :name` after
  #     the def) fire no hook; wrapping Module#private in Ruby breaks the
  #     argument-less `private` form, so we do not;
  #   * methods defined from C after boot, refinements, ISeq/AST inspection;
  #   * module receivers: descendants of a module receiver are not checked.
  module Guard
    MOD_NAME = Module.instance_method(:name)
    SINGLETON_CLASS = Kernel.instance_method(:singleton_class)

    class << self
      attr_reader :manifest, :state

      def install(manifest, state = G)
        @manifest = manifest
        @state = state
        @units = manifest.units.to_h { |u| [u.fetch("id"), u] }
        @names = manifest.units_by_method
        @overrides = {} # name => ObjectSpace::WeakMap{obj => true}
        Module.prepend(ModuleHooks) unless Module < ModuleHooks
        BasicObject.prepend(ObjectHooks) unless BasicObject < ObjectHooks
      end

      def installed? = !@manifest.nil?

      def validate(id, klass: nil)
        unit = @units[id] or return false
        return false unless env_ok? && enabled_unit?(id)
        unit.fetch("facts").all? { |fact| holds?(fact, klass) }
      rescue StandardError => e
        Lowrail.debug("unit #{id}: guard validation raised #{e.class}: #{e.message}")
        false
      end

      # Hot at boot: called for every method definition in the process.
      def reset_method(name)
        ids = @names[name] or return
        ids.each { |id| @state[id] = nil; V[id] = nil }
      end

      # A module was included/prepended/extended: every tracked name it (or
      # its ancestors) defines may now resolve differently. Asking the module
      # for its methods costs ~1.5us for a typical 10-method concern; probing
      # each tracked name costs ~70ns per name, so probe only small manifests.
      def names_of(mod)
        if @names.size <= 16
          @names.each_key.select { |n| mod.method_defined?(n) || mod.private_method_defined?(n) }
        else
          (mod.instance_methods + mod.private_instance_methods).select { |n| @names.key?(n) }
        end
      end

      def reset_module(mod)
        return if @names.empty?
        names_of(mod).each { |n| reset_method(n) }
      end

      # obj got a singleton method (or module) for a tracked name.
      def note_override(obj, name)
        (@overrides[name] ||= ObjectSpace::WeakMap.new)[obj] = true
        reset_method(name)
      end

      def note_extend(mod, obj)
        return if @names.empty?
        names_of(mod).each { |n| note_override(obj, n) }
      end

      private

      # LOWRAIL_UNITS="0,3,7" restricts lowering to those units (used by
      # `lowrail verify --bisect`); LOWRAIL_UNITS="" enables none.
      def enabled_unit?(id)
        list = ENV["LOWRAIL_UNITS"] or return true
        (@enabled_units ||= list.split(",").map { Integer(_1) }).include?(id)
      end

      def env_ok?
        return @env_ok unless @env_ok.nil?
        want = @manifest.rails_env or return (@env_ok = true)
        have = defined?(::Rails) && ::Rails.respond_to?(:env) ? ::Rails.env.to_s : (ENV["RAILS_ENV"] || ENV["RACK_ENV"])
        return false if have.nil? # not decided yet; ask again later
        @env_ok = (have == want).tap { |ok| Lowrail.debug("manifest built for #{want}, running #{have}") unless ok }
      end

      SELF_RECEIVERS = ["@self", "@view"].freeze

      def holds?(fact, klass = nil)
        if SELF_RECEIVERS.include?(fact.fetch("receiver"))
          return false unless klass
          name = fact.fetch("method").to_sym
          return holds_on?(klass, name, fact) && no_instance_override?(klass, name) &&
                 (fact["route"].nil? || route_holds?(klass, name, fact["route"]))
        end
        mod = Object.const_get(fact.fetch("receiver"))
        name = fact.fetch("method").to_sym
        singleton = fact["singleton"]
        holds_on?(singleton ? mod.singleton_class : mod, name, fact) &&
          descendants_agree?(mod, name, singleton) &&
          (singleton || no_instance_override?(mod, name))
      rescue NameError => e # constant or method gone: the fact does not hold
        Lowrail.debug("fact #{fact["receiver"]}#{fact["singleton"] ? "." : "#"}#{fact["method"]}: #{e.class}: #{e.message}")
        false
      end

      # A named-route helper: klass#name must be the method the application's
      # route set defined for that route (its path helper module, compared by
      # identity, since it is anonymous), and the route must still have the
      # path, required parts and defaults the build specialized, with no
      # requirements and no glob (the shape OptimizedUrlHelper handles).
      # Redrawing routes redefines the helpers, which resets the unit, so this
      # is re-checked after every reload.
      def route_holds?(klass, name, route)
        return false unless defined?(::Rails) && ::Rails.respond_to?(:application) && (app = ::Rails.application)
        named = app.routes.named_routes
        return false unless klass.instance_method(name).owner.equal?(named.path_helpers_module)
        r = named.get(route.fetch("name")) or return false
        r.path.spec.to_s == route.fetch("spec") &&
          r.required_parts.map(&:to_s) == route.fetch("parts") &&
          r.defaults.inspect == route.fetch("defaults") &&
          r.path.requirements.empty? && !r.glob?
      end

      def holds_on?(klass, name, fact)
        meth = klass.instance_method(name)
        return false unless meth.source_location&.then { "#{_1[0]}:#{_1[1]}" } == fact["source_location"]
        return false unless visibility_of(klass, name) == fact.fetch("visibility")
        owner = fact.fetch("owner")
        # nil owner = anonymous module (e.g. a route set's helper module),
        # identified by the source location alone.
        return owner_name(meth.owner).nil? if owner.nil?
        owner_name(meth.owner) == owner || same_definition?(meth, owner, name)
      end

      # Same labels as the facts dumper (lowrail/facts.rb#mod_label), read
      # through the core methods so modules overriding `name` do not matter.
      # Anonymous owners never match (their label is not unique).
      def owner_name(mod)
        if (name = MOD_NAME.bind_call(mod)) then name
        elsif mod.singleton_class? && Module === (attached = mod.attached_object)
          (inner = owner_name(attached)) && "#<Class:#{inner}>"
        end
      end

      # True when meth is an alias of the method `name` owned by the module
      # the fact names (same instruction sequence object).
      def same_definition?(meth, owner, name)
        iseq = RubyVM::InstructionSequence.of(meth) or return false
        owner_mod =
          if (m = owner.match(/\A#<Class:(.+)>\z/)) then Object.const_get(m[1]).singleton_class
          else Object.const_get(owner)
          end
        orig = owner_mod.instance_method(name)
        orig.owner == owner_mod && RubyVM::InstructionSequence.of(orig).equal?(iseq)
      rescue NameError, ArgumentError
        false
      end

      def descendants_agree?(klass, name, singleton)
        return true unless klass.is_a?(Class)
        holder = singleton ? :singleton_class.to_proc : :itself.to_proc
        base_meth = holder.(klass).instance_method(name)
        base = RubyVM::InstructionSequence.of(base_meth)
        base_vis = visibility_of(holder.(klass), name)
        stack = klass.subclasses
        while (sub = stack.pop)
          h = holder.(sub)
          m = h.instance_method(name)
          return false unless m == base_meth || (base && RubyVM::InstructionSequence.of(m).equal?(base))
          return false unless visibility_of(h, name) == base_vis
          stack.concat(sub.subclasses)
        end
        true
      end

      def no_instance_override?(klass, name)
        objs = @overrides[name] or return true
        base_meth = klass.instance_method(name)
        base = RubyVM::InstructionSequence.of(base_meth)
        objs.each_key do |obj|
          next unless klass === obj
          m = SINGLETON_CLASS.bind_call(obj).instance_method(name)
          next if m == base_meth || (base && RubyVM::InstructionSequence.of(m).equal?(base))
          return false
        end
        true
      rescue TypeError
        false
      end

      def visibility_of(mod, name)
        if mod.public_method_defined?(name) then "public"
        elsif mod.protected_method_defined?(name) then "protected"
        else "private"
        end
      end
    end

    # Prepended to Module. Every hook calls super, so app and gem hooks that
    # also call super keep working.
    module ModuleHooks
      private

      def method_added(name)
        Guard.reset_method(name)
        super
      end

      def method_removed(name)
        Guard.reset_method(name)
        super
      end

      def method_undefined(name)
        Guard.reset_method(name)
        super
      end

      def append_features(base)
        Guard.reset_module(self)
        super
      end

      def prepend_features(base)
        Guard.reset_module(self)
        result = super
        Loader.prepended_to(base, self) if defined?(Loader)
        result
      end

      def extend_object(obj)
        if Module === obj
          Guard.reset_module(self)
        else
          Guard.note_extend(self, obj)
        end
        super
      end
    end

    # Prepended to BasicObject: singleton_method_added is sent to the object
    # that got the singleton method (a class for `def self.x`, any object for
    # `def obj.x` and Minitest's `obj.stub`).
    module ObjectHooks
      private

      def singleton_method_added(name)
        Lowrail::Guard.singleton_changed(self, name)
        super
      end

      def singleton_method_removed(name)
        Lowrail::Guard.singleton_changed(self, name)
        super
      end

      def singleton_method_undefined(name)
        Lowrail::Guard.singleton_changed(self, name)
        super
      end
    end

    def self.singleton_changed(obj, name)
      return unless @names.key?(name)
      if Module === obj
        reset_method(name)
      else
        note_override(obj, name)
      end
    end
  end
end
