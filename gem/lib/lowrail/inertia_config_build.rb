# frozen_string_literal: true

require "digest"
require_relative "inertia_config"
require_relative "preload_facts"

module Lowrail
  module InertiaConfigBuild
    # Audited constructor/schema/readers, not permission for arbitrary future
    # gem implementations with the same method names.
    AUDITED = {
      "3.21.2" => "77e3005cba6b45843f2ee17171b39f64eab4fbbe20f865b8e017ec46fed9feb7",
      "3.22.0" => "79c6f11db937d9d1ac8197395bdee83cb194ccff10c7844600895dbf2821de99",
      "3.23.0" => "333a986ce17e326d4537c9ce8149a47525da51abc7b9e397057e7ad55a6813fd"
    }.freeze
    module_function

    def build(denied: [])
      target = "InertiaRails::Configuration#bind_controller"
      entry = {"pass" => Passes::InertiaConfig::PASS, "target" => target,
        "site" => "bind_controller", "outcome" => "refused"}
      units = []
      reason = catch(:refused) do
        decline = ->(code) { throw :refused, code }
        decline.call("gem_absent") unless defined?(::InertiaRails::Configuration)
        klass = ::InertiaRails::Configuration
        version = Gem.loaded_specs.fetch("inertia_rails").version.to_s
        decline.call("unsupported_gem_version") unless AUDITED.key?(version)
        decline.call("denylisted") if denied.any? { _1["pass"] == entry["pass"] && (_1["target"] || _1["file"]) == target }
        path = Gem.loaded_specs.fetch("inertia_rails").full_gem_path + "/lib/inertia_rails/configuration.rb"
        decline.call("constructor_override") unless Digest::SHA256.file(path).hexdigest == AUDITED.fetch(version) &&
          !klass.const_defined?(:Configuration, false) && klass.public_method_defined?(:bind_controller) &&
          %i[initialize bind_controller].all? { klass.instance_method(_1).owner.equal?(klass) && klass.instance_method(_1).original_name == _1 && klass.instance_method(_1).source_location&.first == path }
        decline.call("schema_changed") unless klass::OPTION_NAMES.instance_of?(Array) && klass::OPTION_NAMES.frozen? &&
          Passes::InertiaConfig::SINGLETON_METHODS.bind_call(klass::OPTION_NAMES).empty? &&
          klass::OPTION_NAMES == klass::DEFAULTS.keys && klass::OPTION_NAMES.all? { Symbol === _1 } &&
          !klass::OPTION_NAMES.include?(:controller)
        # All dispatched operations bypassed by allocation/copy or used by the
        # residue. Exact facts avoid unrelated Hash/Configuration subclasses.
        dependencies = [[klass, :new, true], [klass, :allocate, true], [klass, :initialize, false],
          [klass, :class, false], [klass, :instance_variable_set, false], [Kernel, :singleton_methods, false],
          [Hash, :new, true], [Hash, :extract!, false], [Array, :each_with_object, false], [Array, :each, false],
          [Array, :==, false], [Symbol, :==, false]] +
          %i[keys default default_proc compare_by_identity? delete has_key? empty? []= class].map { [Hash, _1, false] }
        extract_path = Hash.instance_method(:extract!).source_location&.first
        expected_extract = 'def extract!(*keys); keys.each_with_object(self.class.new) { |key, result| result[key] = delete(key) if has_key?(key) }; end'
        require "prism"
        tokens = ->(src) { Prism.lex(src, version: "current").value.map(&:first).reject { |t| %i[COMMENT NEWLINE NEWLINE_TERMINATOR IGNORED_NEWLINE SEMICOLON EOF].include?(t.type) }.map { |t| [t.type, t.value] } }
        extract_source = extract_path && File.read(extract_path)[/  def extract!\(\*keys\).*?^  end/m]
        decline.call("constructor_override") unless extract_source && tokens.call(extract_source) == tokens.call(expected_extract)
        facts = dependencies.map do |mod, name, singleton|
          holder = singleton ? mod.singleton_class : mod
          method = holder.instance_method(name)
          decline.call("constructor_override") unless method.original_name == name
          unless [klass, Hash].include?(mod) && [:initialize, :extract!].include?(name)
            builtin = (name == :class && method.owner == Kernel && method.source_location&.first == "<internal:kernel>") ||
              (mod == Array && name == :each && method.owner == Array && method.source_location&.first == "<internal:array>")
            decline.call("constructor_override") unless (method.source_location.nil? || builtin) && method.original_name == name
          end
          PreloadFacts.method_fact(mod, name, singleton: singleton).merge("exact" => name != :class, "original_name" => method.original_name.to_s)
        end
        variant = Passes::InertiaConfig::Variant.instance_method(:bind_controller)
        facts << {"receiver" => klass.name, "method" => "bind_controller", "singleton" => false,
          "owner" => Passes::InertiaConfig::Variant.name, "source_location" => variant.source_location.join(":"),
          "visibility" => "public", "exact" => true, "original_name" => "bind_controller"}
        sources = [path, extract_path, __FILE__, variant.source_location.first]
        units << {"pass" => entry["pass"], "kind" => "method", "target" => target, "file" => target,
          "sites" => 1, "facts" => facts, "data" => {"gem_version" => version,
            "original" => klass.instance_method(:bind_controller).source_location,
            "keys" => klass::OPTION_NAMES.map(&:to_s),
            "sources" => sources.uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }}}
        nil
      end
      entry.merge!(reason ? {"reason" => reason} : {"outcome" => "lowered", "reason" => "canonical_schema"})
      {units: units, ledger: [entry]}
    end
  end
end
