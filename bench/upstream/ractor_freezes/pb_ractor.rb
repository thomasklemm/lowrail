require "active_record"
require "active_support/core_ext/object/with"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
early = Class.new(ActiveRecord::Base) { self.table_name = "users" }
late = ActiveSupport::Ractors.with(unshareable_proc_action: :raise) { Class.new(ActiveRecord::Base) { self.table_name = "users" } }
p early: Ractor.shareable?(early.predicate_builder), late: Ractor.shareable?(late.predicate_builder)
ActiveSupport::Ractors.with(unshareable_proc_action: :raise) { ActiveSupport::Ractors.try_make_shareable(early.predicate_builder) }
p early_after_hook: Ractor.shareable?(early.predicate_builder)
p from_ractor: Ractor.new(late) { |m| m.predicate_builder.class.name }.value
