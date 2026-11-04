# Differential for the write path: same output on main and a candidate.
require "bundler/setup"; require "active_record"
ActiveSupport.event_reporter.debug_mode = false
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:items) { |t| t.string :name; t.integer :n, default: 0; t.timestamps; t.datetime :updated_on }
  create_table(:plain) { |t| t.string :name }
  create_table(:subs) { |t| t.references :item; t.string :body; t.timestamps }
end
FIXED = Time.utc(2026, 1, 2, 3, 4, 5)
$now_calls = 0
class << Time; alias_method :orig_now, :now; def now(...) = ($now_calls += 1; $t); end
$t = FIXED
class Item < ActiveRecord::Base
  has_many :subs
  before_update { self.name = "cb-#{name}" if name == "dirty-in-cb" }
  after_commit { $log << "commit #{id}" }
  after_rollback { $log << "rollback #{id}" }
end
class Plain < ActiveRecord::Base; self.table_name = "plain"; end
class Sub < ActiveRecord::Base; belongs_to :item, touch: true; end
class NoTs < ActiveRecord::Base; self.table_name = "items"; self.record_timestamps = false; end
$log = []
sqls = []
ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| sqls << p[:sql] unless p[:name] == "SCHEMA" }
out = []
rec = ->(label, r) { $t += 60; out << [label, r.attributes.except("id").transform_values { _1.is_a?(Time) ? _1.utc.iso8601 : _1 }, r.saved_changes.keys.sort].inspect }
$t += 1
i = Item.create!(name: "a"); rec.("create", i)
$t += 1; i.update!(n: 1); rec.("update", i)
$t += 1; i.save!; rec.("save clean", i)
$t += 1; i.update!(name: "dirty-in-cb"); rec.("dirty in callback", i)
$t += 1; i.update!(updated_at: Time.utc(2020, 1, 1), n: 2); rec.("explicit updated_at", i)
$t += 1; i.update!(updated_on: Time.utc(2021, 1, 1), n: 3); rec.("explicit updated_on", i)
$t += 1; i.save!(touch: false) if i.n = 4; rec.("touch false", i)
$t += 1; i.touch; rec.("touch", i)
$t += 1; i.touch(:updated_on, time: Time.utc(2022, 1, 1)); rec.("touch time", i)
$t += 1; NoTs.find(i.id).tap { _1.update!(n: 9) }.then { rec.("no timestamps", _1) }
$t += 1; p0 = Plain.create!(name: "x"); p0.update!(name: "y"); rec.("no timestamp columns", p0)
$t += 1; s = i.subs.create!(body: "b"); s.update!(body: "c"); rec.("child touch", s); rec.("parent after touch", i.reload)
$t += 1; Item.transaction { i.update!(n: 10); Item.transaction(requires_new: true) { i.update!(n: 11); raise ActiveRecord::Rollback } }; rec.("nested rollback", i.reload)
$t += 1; begin; Item.transaction { i.update!(n: 12); raise "boom" }; rescue => e; out << "error #{e.message}"; end; rec.("rolled back", i.reload)
$t += 1; Item.partial_updates = false; i.update!(n: 13); rec.("partial off", i); i.save!; rec.("partial off clean", i); Item.partial_updates = true
out << $log.inspect
out << sqls.map { _1.gsub(/\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.?\d*/, "T") }.inspect
puts out
puts "Time.now calls: #{$now_calls}"
