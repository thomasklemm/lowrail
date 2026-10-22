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
    ARRAY_EACH = Array.instance_method(:each)
    ANCESTORS = Module.instance_method(:ancestors)

    class << self
      attr_reader :manifest, :state

      def install(manifest, state = G)
        @manifest = manifest
        @state = state
        @units = manifest.units.to_h { |u| [u.fetch("id"), u] }
        @names = manifest.units_by_method
        @targets ||= {}.compare_by_identity
        @targets[nil] = @names # Ordinary facts invalidate by name, on any holder.
        @overrides = {} # name => ObjectSpace::WeakMap{obj => true}
        # Compiler refusals can leave gaps in the manifest's unit IDs.
        K.replace(Array.new((@units.keys.max || -1) + 1, NO_RECEIVER))
        if manifest.refusal_reason
          G.clear
          @state.clear
          V.clear
          return
        end
        install_hooks(manifest)
      end

      # Only selected method facts need ordinary invalidation. Source delivery
      # also needs ModuleHooks to rehook a later Bootsnap prepend. Install the same chain
      # in the explicit off arm; its empty indexes leave app methods untouched.
      def install_hooks(manifest)
        return if manifest.refusal_reason
        selected = ENV["LOWRAIL_UNITS"]&.split(",")&.map { Integer(_1) }
        invalidation = manifest.units.any? do |unit|
          (!selected || selected.include?(unit.fetch("id"))) && !unit.fetch("facts").empty?
        end
        sealed = ENV["LOWRAIL_SEALED"] == "1"
        if invalidation || !manifest.files.empty? || sealed
          observe_mutations(singletons: invalidation || sealed)
        end
      end

      # One installer and one target table for ordinary facts and holder-scoped
      # clients. Explicit sealed setup calls this equally in both arms before
      # boot; publishing a client never changes an application holder.
      def observe_mutations(singletons: true)
        @names ||= {}
        @targets ||= {}.compare_by_identity
        @targets[nil] = @names
        Module.prepend(ModuleHooks) unless Module < ModuleHooks
        BasicObject.prepend(ObjectHooks) if singletons && !(BasicObject < ObjectHooks)
      end

      # Clients supply only the invalidation action. Guard owns holder/name
      # registration, inherited dispatch and mutation notification. nil names
      # register ancestry changes; unrelated lazy method definitions stay live.
      def watch(facts, &client)
        resolved = {}.compare_by_identity
        facts.each do |holder, names|
          names = [*names.map(&:to_sym), :method_missing, :respond_to_missing?, nil].to_h { [_1, true] }
          ANCESTORS.bind_call(holder).each { (resolved[_1] ||= {}).merge!(names) }
        end
        # Enumerate only already-existing eigenclasses. Calling singleton_class
        # here would itself change the holder/ancestry surface we must preserve.
        ObjectSpace.each_object(Class) do |holder|
          next unless holder.singleton_class? && (names = resolved[holder.attached_object])
          ANCESTORS.bind_call(holder).each { (resolved[_1] ||= {}).merge!(names) }
        end
        resolved.each do |holder, names|
          targets = (@targets[holder] ||= {})
          names.each_key { |name| (targets[name] ||= []) << client unless targets[name]&.include?(client) }
        end
      end

      def changed(holder, name = nil)
        reset_method(name) if name
        return unless @targets && Module === holder
        names = @targets[holder] || holder.singleton_class? && @targets[holder.attached_object]
        invalidate(names[name]) if names
      end

      def installed? = !@manifest.nil?

      def validate(id, klass: nil)
        unit = @units[id] or return false
        return false if @manifest.refusal_reason
        return false unless env_ok? && enabled_unit?(id)
        unit.fetch("facts").all? { |fact| holds?(fact, klass) }
      rescue StandardError => e
        Lowrail.debug("unit #{id}: guard validation raised #{e.class}: #{e.message}")
        false
      end

      # Hot at boot: called for every method definition in the process.
      def reset_method(name)
        invalidate(@names[name])
      end

      def invalidate(clients)
        return unless clients
        # Late YJIT.enable temporarily undefines Array#each while replacing it.
        # Invalidation must not dispatch through the method being invalidated.
        ARRAY_EACH.bind_call(clients) do |client|
          if Integer === client
            @state[client] = nil; V[client] = nil; K[client] = NO_RECEIVER
          else
            client.call
          end
        end
      end

      # A module was included/prepended/extended: every tracked name it (or
      # its ancestors) defines may now resolve differently. Asking the module
      # for its methods costs ~1.5us for a typical 10-method concern; probing
      # each tracked name costs ~70ns per name, so probe only small manifests.
      # Collect before invalidating; unrelated modules need no result array.
      def names_of(mod)
        if @names.size <= 16
          names = nil
          @names.each_key do |n|
            (names ||= []) << n if mod.method_defined?(n) || mod.private_method_defined?(n)
          end
          names
        else
          (mod.instance_methods + mod.private_instance_methods).select { |n| @names.key?(n) }
        end
      end

      def reset_module(mod)
        return if @names.empty?
        names_of(mod)&.each { |n| reset_method(n) }
      end

      # obj got a singleton method (or module) for a tracked name.
      def note_override(obj, name)
        (@overrides[name] ||= ObjectSpace::WeakMap.new)[obj] = true
        reset_method(name)
      end

      def note_extend(mod, obj)
        return if @names.empty?
        names_of(mod)&.each { |n| note_override(obj, n) }
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
        mod = Lowrail.loaded_constant(fact.fetch("receiver")) or return false
        name = fact.fetch("method").to_sym
        singleton = fact["singleton"]
        holds_on?(singleton ? mod.singleton_class : mod, name, fact) &&
          # Runtime plans instantiate a specific class and guard that class,
          # rather than specializing a method inherited by arbitrary children.
          (fact["exact"] || descendants_agree?(mod, name, singleton)) &&
          (singleton || no_instance_override?(mod, name))
      rescue NameError => e # constant or method gone: the fact does not hold
        Lowrail.debug("fact #{fact["receiver"]}#{fact["singleton"] ? "." : "#"}#{fact["method"]}: #{e.class}: #{e.message}")
        false
      end

      # A named-route helper: klass#name must be the method the application's
      # route set defined for that route (its path or URL helper module, compared by
      # identity, since it is anonymous), and the route must still have the
      # path, required parts and defaults the build specialized, with no
      # requirements and no glob (the shape OptimizedUrlHelper handles). Glob
      # segments are read from the spec (`*name`): production apps free the
      # route AST after boot, so Route#glob? raises there.
      # Redrawing routes redefines the helpers, which resets the unit, so this
      # is re-checked after every reload.
      def route_holds?(klass, name, route)
        return false unless defined?(::Rails) && ::Rails.respond_to?(:application) && (app = ::Rails.application)
        named = app.routes.named_routes
        helpers = name.end_with?("_url") ? named.url_helpers_module : named.path_helpers_module
        return false unless klass.instance_method(name).owner.equal?(helpers)
        r = named.get(route.fetch("name")) or return false
        r.path.spec.to_s == route.fetch("spec") &&
          r.required_parts.map(&:to_s) == route.fetch("parts") &&
          r.defaults.inspect == route.fetch("defaults") &&
          r.path.requirements.empty? && !r.path.spec.to_s.include?("*")
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
          if (m = owner.match(/\A#<Class:(.+)>\z/)) then Lowrail.loaded_constant(m[1])&.singleton_class
          else Lowrail.loaded_constant(owner)
          end
        return false unless owner_mod
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
        Guard.changed(self, name)
        super
      end

      def method_removed(name)
        Guard.changed(self, name)
        super
      end

      def method_undefined(name)
        Guard.changed(self, name)
        super
      end

      def append_features(base)
        Guard.changed(base)
        Guard.reset_module(self)
        super
      end

      def prepend_features(base)
        Guard.changed(base)
        Guard.reset_module(self)
        result = super
        Loader.prepended_to(base, self) if defined?(Loader)
        result
      end

      def extend_object(obj)
        Guard.changed(obj)
        if Module === obj
          Guard.reset_module(self)
        else
          Guard.note_extend(self, obj)
        end
        super
      end

      # Completion callbacks also cover modules that override the feature hook
      # without super. An ancestry notification is conservative, not a claim
      # that Ruby necessarily changed the destination's ancestor chain.
      def included(base)
        Guard.changed(base)
        super
      end

      def prepended(base)
        Guard.changed(base)
        super
      end

      def extended(obj)
        Guard.changed(obj)
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
      if Module === obj
        changed(obj, name)
      elsif @names.key?(name)
        note_override(obj, name)
      end
    end
  end
end
