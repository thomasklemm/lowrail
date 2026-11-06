require "bundler/setup"
require "active_record"
require "ancestry"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:owners) { |t| t.string :name }
  create_table(:nodes) { |t| t.string :ancestry, collation: "BINARY"; t.string :name; t.integer :owner_id; t.integer :ancestry_depth, default: 0; t.integer :children_count, default: 0; t.timestamps }
end
ENTRY = []
class Node < ActiveRecord::Base
  belongs_to :owner, optional: true, autosave: true
  has_ancestry ancestry_format: :materialized_path2, cache_depth: true, counter_cache: true, touch: true, orphan_strategy: :adopt

  def sane_ancestor_ids?
    ENTRY << [caller_locations(2, 1).first.label, validation_context]
    true
  end
end
class Owner < ActiveRecord::Base
  has_many :nodes, autosave: true
  accepts_nested_attributes_for :nodes
  validates_associated :nodes
end
o = Owner.create!(name: "o")
root = Node.create!(name: "r", owner: o); other = Node.create!(name: "x", owner: o)
child = Node.create!(name: "c", parent: root, owner: o); Node.create!(name: "g", parent: child)
def run(label) = (ENTRY.clear; r = (yield rescue $!.class); puts "#{label.ljust(52)} r=#{r.inspect[0,20].ljust(20)} entry=#{ENTRY.inspect}")
run("owner.save(context: :import) w/ autosave child move") { ow = Owner.find(o.id); n = ow.nodes.find { _1.id == child.id }; n.parent = other; ow.name = "o2"; ow.save(context: :import) }
run("nested attrs save(context: :import)") { ow = Owner.find(o.id); ow.update(nodes_attributes: [{ id: child.id, parent_id: root.id }]); ow }
run("nested attrs via save(context:)") { ow = Owner.find(o.id); ow.assign_attributes(nodes_attributes: [{ id: child.id, parent_id: other.id }]); ow.save(context: :import) }
run("node.save(context: :import) with autosave owner") { n = Node.find(child.id); n.owner.name = "o3"; n.parent = root; n.save(context: :import) }
run("update_strategy sql n/a on sqlite; destroy adopt") { Node.find(child.id).destroy }
