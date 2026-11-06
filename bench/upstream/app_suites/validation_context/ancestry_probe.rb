# Usage: ruby ancestry_probe.rb [original|no_context]
# Shows what ancestry 5.1.0's sane_ancestor_ids? sees as validation_context, and whether
# dropping its context save/clear/restore changes any outcome.
require "bundler/setup"
require "active_record"
require "ancestry"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:nodes) { |t| t.string :ancestry, collation: "BINARY"; t.string :name }
end

class ContextSpyValidator < ActiveModel::EachValidator
  SEEN = []
  def validate_each(record, attribute, value)
    SEEN << record.validation_context
    record.errors.add(attribute, "rejected in :strict") if record.validation_context == :strict
  end
end

class Node < ActiveRecord::Base
  has_ancestry ancestry_format: :materialized_path2
  validates :name, presence: true, on: :create
  validates :ancestry, context_spy: true
end

ENTRY = []
Ancestry::InstanceMethods.prepend(Module.new do
  def sane_ancestor_ids?
    ENTRY << [caller_locations(1, 1).first.label, validation_context]
    super
  end
end)

if ARGV[0] == "no_context"
  Ancestry::InstanceMethods.class_eval do
    def sane_ancestor_ids?
      errors.clear
      attribute = self.class.ancestry_column
      ancestry_value = send(attribute)
      return true unless ancestry_value
      self.class.validators_on(attribute).each { |v| v.validate_each(self, attribute, ancestry_value) }
      ancestry_exclude_self
      errors.none?
    end
  end
end

def run(label)
  ENTRY.clear
  ContextSpyValidator::SEEN.clear
  result = begin
    yield.inspect
  rescue => e
    "#{e.class}: #{e.message[0, 60]}"
  end
  puts format("%-44s result=%-28s entry_contexts=%-30s validator_saw=%s", label, result[0, 28], ENTRY.map(&:last).inspect, ContextSpyValidator::SEEN.inspect)
end

root = Node.create!(name: "root")
other = Node.create!(name: "other")
child = Node.create!(name: "child", parent: root)
Node.create!(name: "grandchild", parent: child)

run("update!(parent:) with descendants") { child.update!(parent: other); child.reload.descendants.map(&:name) }
run("save(context: :strict) reparent") { child.parent = root; child.save(context: :strict) }
run("save!(context: :import) reparent") { child.parent = other; child.save!(context: :import) }
run("update_attribute(:parent) (no validation)") { child.update_attribute(:parent, root); child.reload.descendants.map(&:name) }
Node.where(name: "child").update_all(name: nil) # stored record that is invalid for another reason
run("reparent record with invalid name column") { c = Node.find(child.id); c.parent = other; c.save(context: :update) }
run("check_ancestry_integrity!") { Node.check_ancestry_integrity! }
Node.where(id: child.id).update_all(ancestry: "/x/")
run("check_ancestry_integrity! with bad ancestry") { Node.check_ancestry_integrity! }
run("restore_ancestry_integrity!") { Node.restore_ancestry_integrity!; Node.find(child.id).ancestry }
run("sane_ancestor_ids? called inside valid?(:strict)") do
  n = Node.find(child.id)
  n.singleton_class.validate { errors.add(:base, "insane") unless sane_ancestor_ids? }
  [n.valid?(:strict), n.errors.full_messages]
end
