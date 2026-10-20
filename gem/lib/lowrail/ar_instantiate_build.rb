# frozen_string_literal: true

require "json"
require "digest"
require_relative "ar_instantiate"
require_relative "preload_facts"

module Lowrail
  module ARInstantiateBuild
    # Audited Rails 8.1.3, 8.1.4 and 8.2 alpha (e3d5c569d217).
    # New Rails bodies require review, not merely a newly recorded fingerprint.
    AUDITED = {
      "querying.rb" => %w[3d51fd07ee5bdb2a54bf6c9c301102a6eecaaed9a4b8b27140388c6f0afa6050 1b04b14115fd59910be8bd3ac817535eb232dcb75c64b649591c49f089d1a604 c63a6f147d7b0fd7baba4c07d665138eb31de05608e456e8d3d555c915014862],
      "persistence.rb" => %w[eb8d37094567634d8fcfaa0876234ac52e1e3dab1c8efd50c036b0b15b9329f4 f5ad7f51dc23c2b996dac4d25894a0c75c12fe140c871e39bdc2120d54ed7d58 eee8add6f4a914d133f7638bc006c08b6696e692d5a663b4f5eee34ca2c61d6f],
      "model_schema.rb" => %w[ac345e5094c9045ca04485b5ada74bf0869dafa02c343cd74675bd415598bc24 c593dd71fb08f82742b72dad61011c66aaf06019d860ddb85f53672ff13d5214 c9e2a46f7d4978d7f71ea04de25a2914dfd411cea018620be7f3d68b5040f93e],
      "schema_context.rb" => %w[c5005016678a863c22f1476c77d9bc3fb5bbc2c75423a3870d884f576e5eb0f8]
    }.freeze
    module_function

    def build(denied: [])
      units, ledger = [], []
      pass = ARInstantiate::PASS
      unless defined?(ActiveRecord::Base)
        return {units: units, ledger: [{"pass" => pass, "outcome" => "refused", "reason" => "framework_absent"}]}
      end
      ActiveRecord::Base.descendants.sort_by { _1.name.to_s }.each do |klass|
        next if klass.abstract_class? || !klass.name || !klass.table_exists?
        reason = nil
        reason = "denylisted by verify --bisect" if denied.any? { _1["pass"] == pass && _1["file"] == klass.name }
        original = klass.method(:_load_from_sql)
        unless original.owner == ActiveRecord::Querying && original.source_location&.first&.end_with?("/active_record/querying.rb")
          reason ||= "custom _load_from_sql"
        end
        # This only removes the homogeneous instantiate_instance_of dispatch
        # and hoists attributes_builder. Never bypass a customized dispatch.
        dispatch = klass.method(:instantiate_instance_of)
        unless dispatch.owner == ActiveRecord::Persistence::ClassMethods && dispatch.source_location&.first&.end_with?("/active_record/persistence.rb")
          reason ||= "custom instantiate_instance_of"
        end
        builder_method = klass.method(:attributes_builder)
        unless builder_method.owner == ActiveRecord::ModelSchema::ClassMethods && builder_method.source_location&.first&.end_with?("/active_record/model_schema.rb")
          reason ||= "custom attributes_builder"
        end
        sources = [original, dispatch, builder_method].filter_map { _1.source_location&.first }.uniq
        unless sources.size == 3 && sources.all? { File.file?(_1) && AUDITED.fetch(File.basename(_1), []).include?(Digest::SHA256.file(_1).hexdigest) }
          reason ||= "unaudited Rails implementation"
        end
        dependencies = alpha_dependencies(klass)
        framework = %w[activerecord activemodel activesupport].map { Gem.loaded_specs.fetch(_1).full_gem_path + "/" }
        dependencies.each do |mod, name, singleton|
          method = singleton ? mod.method(name) : mod.instance_method(name)
          path = method.source_location&.first
          reason ||= "custom builder dependency #{mod.name}#{singleton ? '.' : '#'}#{name}" if path && !path.start_with?(*framework)
          if path&.end_with?("/schema_context.rb") && !AUDITED.fetch("schema_context.rb").include?(Digest::SHA256.file(path).hexdigest)
            reason ||= "unaudited schema context"
          end
          sources << path if path
        end
        ledger << { "file" => klass.name, "method" => "#{klass.name}._load_from_sql", "pass" => pass,
          "outcome" => reason || "lowered (homogeneous results only)" }
        next if reason
        klass.define_attribute_methods
        facts = %i[attributes_builder instantiate_instance_of].map do |name|
          PreloadFacts.method_fact(klass, name, singleton: true)
        end
        dependencies.each { |mod, name, singleton| facts << PreloadFacts.method_fact(mod, name, singleton: singleton) }
        # Include the replaced name so include/prepend/extend resets this unit.
        facts << { "receiver" => klass.name, "method" => "_load_from_sql", "singleton" => true,
          "owner" => "#<Class:#{klass.name}>", "source_location" => "lowrail:ar_instantiate:#{klass.name}:2",
          "visibility" => "public", "exact" => true }
        # Initialization, callbacks, type filtering and build_from_database
        # remain live. Alpha's builder construction also needs the facts above.
        sources.concat([__FILE__, ARInstantiate.method(:source).source_location.first,
          File.expand_path("ar_guard.rb", __dir__)])
        units << { "kind" => "runtime", "file" => klass.name,
          "pass" => pass, "facts" => facts,
          "ar_instantiate" => { "model" => klass.name, "rails_version" => Rails.version,
            "original" => ARInstantiate.original_fact(original),
            "sources" => sources.uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] } } }
      rescue StandardError => e
        ledger << { "file" => klass.name, "pass" => pass, "outcome" => "declined: #{e.class}" }
      end
      warn "[lowrail] AR instantiate: #{units.size} model variants"
      {units: units, ledger: ledger}
    end

    # 8.1 memoizes the builder itself. Alpha reconstructs it on each lookup,
    # so its getter/constructor closure must also be certified, not just pinned
    # if an app has replaced a getter with request-dependent behavior.
    def alpha_dependencies(klass)
      return [] unless defined?(ActiveRecord::ModelSchema::SchemaContext)
      context = ActiveRecord::ModelSchema::SchemaContext
      %i[schema_context schema_loaded? column_names primary_key primary_key_definition _primary_key_definition].map { [klass, _1, true] } +
        %i[attributes model_class schema_loaded? column_names].map { [context, _1, false] } +
        %i[builder context defaults types Array].map { [context::Attributes, _1, false] } +
        %i[initialize build_from_database types default_attributes].map { [ActiveModel::AttributeSet::Builder, _1, false] } +
        [[ActiveSupport::Ractors, :[], true], [ActiveModel::AttributeSet, :except, false],
         [ActiveModel::AttributeSet, :attributes, false], [ActiveModel::AttributeSet::Builder, :new, true],
         [Array, :-, false], [Hash, :except, false]]
    end
  end
end
