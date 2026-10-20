# frozen_string_literal: true

require "json"
require "digest"
require_relative "preload_facts"
require_relative "preload_plans"

module Lowrail
  module PreloadBuild
    module_function

    def build(denied: [])
      units, ledger = [], []
      reason = "denylisted by verify --bisect" if denied.any? { _1["pass"] == "active_record/preload_plans" }
      if defined?(ActiveRecord::Associations::Preloader)
        preloader = ActiveRecord::Associations::Preloader
        framework = Gem.loaded_specs.fetch("activerecord").full_gem_path + "/"
        # Stable app wrappers are not equivalent to the Rails code we bypass.
        # Recording their source as a fact would merely pin the wrong program.
        [preloader, preloader::Batch, preloader::Branch].each do |mod|
          (mod.instance_methods(false) + mod.private_instance_methods(false)).uniq.each do |name|
            unless mod.instance_method(name).source_location&.first&.start_with?(framework)
              reason ||= "non-certified #{mod.name}##{name}"
            end
          end
        end
      end
      if reason
        ledger << { "pass" => "active_record/preload_plans", "outcome" => reason }
        return {units: units, ledger: ledger}
      end
      models, edges, types, facts = {}, {}, {}, []
      classes = defined?(ActiveRecord::Base) ? ActiveRecord::Base.descendants : []
      classes.sort_by { _1.name.to_s }.each do |klass|
        next if klass.abstract_class? || !klass.name || !klass.table_exists?
        klass.reflect_on_all_associations.each do |r|
          label = "#{klass.name}##{r.name}"
          reason = PreloadFacts.decline(r, klass)
          ledger << { "method" => label, "pass" => "active_record/preload_plans", "outcome" => reason || "eligible (tree checked at runtime)" }
          next if reason
          [klass, r.klass].each do |k|
            models[k.name] ||= PreloadFacts.model(k)
            facts << PreloadFacts.method_fact(k, :association)
            PreloadFacts::SCOPE_METHODS.each do |name|
              facts << PreloadFacts.method_fact(k, name, singleton: true)
            end
            # Relations are model-specific generated classes; a CollectionProxy
            # override is irrelevant, an override on this relation is not.
            PreloadFacts::RELATION_METHODS.each do |name|
              facts << PreloadFacts.method_fact(k.unscoped.class, name)
            end
          end
          PreloadFacts::REFLECTION_METHODS.each do |name|
            facts << PreloadFacts.method_fact(r.class, name)
          end
          PreloadFacts::ASSOCIATION_METHODS.each { |name| facts << PreloadFacts.method_fact(r.association_class, name) }
          facts << PreloadFacts.method_fact(r.association_class, :new, singleton: true)
          PreloadFacts.scope_types(r).each_value do |type|
            PreloadFacts::TYPE_METHODS.each { |name| facts << PreloadFacts.method_fact(type.class, name) }
            types[type.class.name] ||= PreloadFacts.type_methods(type.class)
          end
          edges[label] = PreloadFacts.reflection(r)
        rescue StandardError => e
          ledger << { "method" => label, "pass" => "active_record/preload_plans", "outcome" => "declined: #{e.class}" }
        end
      end
      unless edges.empty?
        preloader = ActiveRecord::Associations::Preloader
        originals = PreloadPlans::Hook.instance_methods(false).map { |name| PreloadFacts.method_fact(preloader, name) }
        originals << PreloadFacts.method_fact(preloader, :initialize)
        [preloader, preloader::Batch, preloader::Association, preloader::Association::LoaderQuery,
         preloader::Association::LoaderRecords, preloader::Branch,
         ActiveRecord::Reflection::AssociationReflection, ActiveRecord::Relation, PreloadPlans::Hook].each do |mod|
          (mod.instance_methods(false) + mod.private_instance_methods(false)).uniq.each do |name|
            next if mod == preloader && originals.any? { _1["method"] == name.to_s }
            facts << PreloadFacts.method_fact(mod, name)
          end
        end
        # Pin the implementation of private Rails APIs used by this pass.
        files = (facts + originals).filter_map { _1["source_location"]&.sub(/:\d+\z/, "") }.uniq
        files.concat(types.values.flat_map(&:values).flatten(1).map(&:first))
        files << PreloadFacts.method(:decline).source_location.first
        edges.each_value { |e| files << e["scope"].first if e["scope"] }
        units << { "kind" => "runtime", "file" => "active_record/preload_plans",
          "pass" => "active_record/preload_plans", "facts" => facts.uniq,
          "preload_facts" => { "models" => models, "edges" => edges,
            "originals" => originals, "types" => types,
            "rails_version" => Rails.version, "sources" => files.uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] } } }
      end
      warn "[lowrail] preload plans: #{edges.size} eligible associations, #{ledger.count { _1["pass"] == "active_record/preload_plans" } - edges.size} declined"
      {units: units, ledger: ledger}
    end
  end
end
