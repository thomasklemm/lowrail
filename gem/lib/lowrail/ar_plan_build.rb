# frozen_string_literal: true

require "json"
require "digest"
require "rbconfig"
require_relative "ar_plan_facts"
require_relative "ar_plan_sites"
require_relative "ar_plans"

module Lowrail
  module ARPlanBuild
    module_function

    def run(dir)
      path = File.join(dir, "manifest.json")
      ledger_path = File.join(dir, "ledger.json")
      manifest = JSON.parse(File.read(path))
      ledger = JSON.parse(File.read(ledger_path))
      manifest["units"].reject! { _1["pass"] == "active_record/ar_plans" }
      ledger.reject! { %w[active_record/ar_plans active_record/ar_plans_survey].include?(_1["pass"]) }
      ledger.concat(ARPlanSites.inventory(Rails.root.to_s)) if Rails.respond_to?(:root)
      models, edges, facts, originals = {}, {}, [], []
      denied = File.file?(File.join(dir, "denylist.json")) && JSON.parse(File.read(File.join(dir, "denylist.json"))).any? { _1["pass"] == "active_record/ar_plans" }
      ActiveRecord::Base.descendants.sort_by { _1.name.to_s }.each do |owner|
        next if !owner.name || owner.abstract_class? || !owner.table_exists?
        owner.reflect_on_all_associations.each do |reflection|
          label = "#{owner.name}##{reflection.name}"
          info, reason = ARPlanFacts.scope_info(reflection)
          reason ||= ARPlanFacts.decline(reflection, info)
          reason = "denylisted by verify --bisect" if denied
          ledger << { "pass" => "active_record/ar_plans", "method" => label, "outcome" => reason || "eligible scoped reader" }
          next if reason
          [owner, reflection.klass].each do |model|
            models[model.name] ||= PreloadFacts.model(model)
            PreloadFacts::SCOPE_METHODS.each { facts << PreloadFacts.method_fact(model, _1, singleton: true) }
            facts << PreloadFacts.method_fact(model, :_read_attribute)
            [model.unscoped.class, model.send(:relation_delegate_class, ActiveRecord::AssociationRelation)].each do |relation|
              receiver = Module.instance_method(:name).bind_call(relation)
              %i[exec_main_query initialize_copy assert_modifiable!].each { originals << PreloadFacts.method_fact(relation, _1).merge("receiver" => receiver) }
              names = ActiveRecord::QueryMethods.instance_methods(false) + ActiveRecord::QueryMethods.private_instance_methods(false)
              (names - %i[assert_modifiable!]).each {
                # Rails deliberately disguises a model-specific relation's
                # .name as its superclass. Guard the actual constant instead.
                facts << PreloadFacts.method_fact(relation, _1).merge("receiver" => receiver)
              }
            end
          end
          %i[target_scope association_scope scope klass].each { facts << PreloadFacts.method_fact(reflection.association_class, _1) }
          originals << PreloadFacts.method_fact(reflection.association_class, :skip_statement_cache?)
          PreloadFacts::REFLECTION_METHODS.each { facts << PreloadFacts.method_fact(reflection.class, _1) }
          ARPlanFacts.bind_columns(reflection, info).each do |column|
            type = reflection.klass.type_for_attribute(column)
            type.class.ancestors.each do |holder|
              next unless holder.name && ![Object, Kernel, BasicObject].include?(holder)
              names = holder.instance_methods(false) + holder.private_instance_methods(false)
              (names & PreloadFacts::TYPE_METHODS).each { facts << PreloadFacts.method_fact(holder, _1) }
            end
          end
          edges[label] = { "owner" => owner.name, "name" => reflection.name.to_s,
            "scope" => info, "reflection" => PreloadFacts.reflection(reflection) }
        rescue StandardError => e
          ledger << { "pass" => "active_record/ar_plans", "method" => label, "outcome" => "declined: #{e.class}: #{e.message.lines.first.strip}" }
        end
      end
      unless edges.empty?
        adapters = models.keys.map { Object.const_get(_1).with_connection(&:class) }.uniq
        adapters.each do |adapter|
          # Arel visitors delegate quoting and compilation to the adapter.
          # Guard the concrete implementation, including inherited methods,
          # without requiring other adapter subclasses to agree with it.
          names = adapter.instance_methods + adapter.private_instance_methods + adapter.protected_instance_methods
          names -= Object.instance_methods + Object.private_instance_methods + Object.protected_instance_methods
          names.uniq.each { facts << PreloadFacts.method_fact(adapter, _1).merge("exact" => true) }
          %i[quote_table_name quote_column_name].each do |name|
            facts << PreloadFacts.method_fact(adapter, name, singleton: true).merge("exact" => true) if adapter.respond_to?(name)
          end
        end
        holders = [ActiveRecord::QueryMethods, ActiveRecord::Relation::WhereClause,
          ActiveRecord::PredicateBuilder, ActiveRecord::TableMetadata, ActiveRecord::Relation,
          ActiveRecord::Associations::AssociationScope, ActiveRecord::Associations::Association]
        holders.concat(ObjectSpace.each_object(Module).select { _1.name&.start_with?("Arel::") })
        holders.each do |holder|
          names = holder.instance_methods(false) + holder.private_instance_methods(false) + holder.protected_instance_methods(false)
          names.uniq.each do |name|
            next if holder == ActiveRecord::Relation && %i[exec_main_query initialize_copy assert_modifiable!].include?(name)
            next if holder == ActiveRecord::Associations::Association && name == :skip_statement_cache?
            facts << PreloadFacts.method_fact(holder, name)
          end
        end
        originals.concat(%i[exec_main_query initialize_copy assert_modifiable!].map { PreloadFacts.method_fact(ActiveRecord::Relation, _1) })
        originals << PreloadFacts.method_fact(ActiveRecord::Associations::Association, :skip_statement_cache?)
        originals.uniq!
        # Track these names for invalidation without asking Guard to match a
        # framework definition hidden by our own prepend.
        %i[exec_main_query initialize_copy assert_modifiable!].each { facts << PreloadFacts.method_fact(ARPlans::RelationHook, _1) }
        facts << PreloadFacts.method_fact(ARPlans::AssociationHook, :skip_statement_cache?)
        files = (facts + originals).filter_map { _1["source_location"]&.sub(/:\d+\z/, "") }
        # Stable method definitions are not a purity certificate for an app's
        # replacement planner/visitor/quoter. Only the framework path is audited.
        trusted = %w[activerecord activemodel activesupport].map { Gem.loaded_specs.fetch(_1).full_gem_path + "/" }
        trusted.concat([__dir__ + "/", RbConfig::CONFIG.fetch("rubylibdir") + "/"])
        if (custom = files.find { !_1.start_with?(*trusted) })
          ledger.each do |entry|
            entry["outcome"] = "custom planning implementation: #{custom}" if entry["outcome"] == "eligible scoped reader"
          end
          edges.clear
        else
          files.concat([__FILE__, ARPlanFacts.method(:scope_info).source_location.first,
            ARPlans.method(:tag).source_location.first, PreloadFacts.method(:scope).source_location.first])
          edges.each_value { files << _1.fetch("reflection").fetch("scope").first }
          id = (manifest["units"].map { _1.fetch("id") }.max || -1) + 1
          manifest["units"] << { "id" => id, "kind" => "runtime", "file" => "active_record/ar_plans",
            "pass" => "active_record/ar_plans", "facts" => facts.uniq,
            "ar_plans" => { "edges" => edges, "models" => models, "originals" => originals,
              "rails_version" => Rails.version, "sources" => files.uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] } } }
        end
      end
      Lowrail.write_json(path, manifest)
      Lowrail.write_json(ledger_path, ledger)
      warn "[lowrail] AR plans: #{edges.size} eligible scoped readers, #{ledger.count { _1["pass"] == "active_record/ar_plans" } - edges.size} refused"
    end
  end
end
