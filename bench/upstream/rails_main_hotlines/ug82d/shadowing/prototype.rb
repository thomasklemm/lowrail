# Prototype: report when a model class method is shadowed on relations by a
# public Relation method. Loaded after active_record; checks only at method
# definition (def self., class << self, define_singleton_method) and on extend.
module ShadowCheck
  HITS = []
  # Relation forwards these to the model (Delegation), so the model's own method still runs.
  FORWARDED = %i[primary_key with_connection connection table_name transaction sanitize_sql_like unscoped name].freeze

  def self.shadowing_owner(model, name)
    return if FORWARDED.include?(name)
    relation = ActiveRecord::Relation
    return unless relation.public_method_defined?(name)
    owner = relation.instance_method(name).owner
    owner unless owner == Object || owner == Kernel || owner == BasicObject || owner.name&.start_with?("ActiveSupport::")
  end

  def self.check(model, name, source)
    return if model == ActiveRecord::Base
    return unless (owner = shadowing_owner(model, name))
    HITS << { model: model.name, name: name, owner: owner.name, source: source,
              location: caller_locations.find { !_1.path.include?("/active") && _1.path != __FILE__ }&.to_s }
  end

  module ClassMethods
    private def singleton_method_added(name)
      super
      ShadowCheck.check(self, name, singleton_class.instance_method(name).source_location&.first) if singleton_class.instance_method(name).owner == singleton_class
    end

    def extend(*mods)
      super.tap do
        mods.each do |mod|
          next if mod.name&.start_with?("ActiveRecord::", "ActiveModel::", "ActiveSupport::")
          mod.public_instance_methods(false).each { ShadowCheck.check(self, _1, mod.instance_method(_1).source_location&.first) }
        end
      end
    end
  end
end

ActiveRecord::Base.singleton_class.prepend(ShadowCheck::ClassMethods)
