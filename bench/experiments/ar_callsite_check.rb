# frozen_string_literal: true

# Executable differential, not a general support certificate. SQLite only.
require "active_record"
require "json"
require "digest"
require "tmpdir"
require_relative "ar_callsite"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:f_writers) { |t| t.string :name }
  create_table(:f_posts) do |t|
    t.integer :writer_id
    t.string :type
    t.integer :status, default: 0
    t.string :title
    t.string :payload
  end
end

class FWriter < ActiveRecord::Base
  has_many :posts, class_name: "FPost", foreign_key: :writer_id
end
class FPost < ActiveRecord::Base
  belongs_to :writer, class_name: "FWriter"
  enum :status, {draft: 0, live: 1}
  scope :ordered, -> { order(title: :desc) }
  after_find { ($callbacks ||= []) << ["find", id] }
  after_initialize { ($callbacks ||= []) << ["initialize", id] }
end
class FSpecialPost < FPost; end
class FScopedPost < FPost
  default_scope { where(status: :live) }
end
class FConstrainedPost < FPost
  self.inheritance_column = :_disabled_type
  query_constraints :writer_id, :id
end

FWriter.insert_all!([{id: 1, name: "Z"}, {id: 2, name: "A"}])
FPost.insert_all!([
  {id: 1, writer_id: 1, type: nil, title: "b", status: 0, payload: nil},
  {id: 2, writer_id: 2, type: "FSpecialPost", title: "a", status: 1, payload: "x"},
  {id: 3, writer_id: 1, type: nil, title: "z", status: 1, payload: ""},
  {id: 4, writer_id: 2, type: nil, title: "c", status: 0, payload: "y"}])

events = []
ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  payload = args.last
  next if payload[:name] == "SCHEMA"
  events << [payload[:sql].b, payload[:name], payload[:binds].map { Lowrail::ARShadow.bind(_1) },
    !!payload[:cached], payload[:row_count]]
end

def snapshot(call, enabled, events)
  ARCallsite.enabled = enabled
  $callbacks = []
  events.clear
  rows = call.call
  result = rows.map do |row|
    attrs = row.attributes
    [row.class.name, attrs, row.changed?, row.readonly?, row.strict_loading?,
      row.association(:writer).loaded? ? row.writer&.attributes : :unloaded]
  end
  [result, $callbacks.dup, events.dup]
rescue ActiveModel::MissingAttributeError => error
  [error.class.name, error.message, $callbacks.dup, events.dup]
end

ARCallsite.install
ARCallsite.shadow = true
cases = []
[FPost, FSpecialPost, FScopedPost].each do |model|
  [1, 2, 99, nil].each do |owner|
    [:draft, :live, nil].each do |state|
      [0, 1, 3].each do |limit|
        cases << -> { model.where(writer_id: owner, status: state).ordered.limit(limit).offset(1).includes(:writer).to_a }
      end
    end
  end
end
[[1, 3], [2], [], [4, 99, 1]].each do |ids|
  cases << -> { FPost.where(id: ids).order(id: :desc).preload(:writer).to_a }
end
cases.concat([
  -> { FPost.where(id: 1..3).to_a }, # deliberate unsupported Between
  -> { FPost.where(id: 1).or(FPost.where(status: :live)).ordered.to_a },
  -> { FPost.where.not(payload: nil).to_a },
  -> { FPost.select(:id, :title).where(writer_id: 1).to_a },
  -> { FPost.joins(:writer).where(f_writers: {name: "A"}).to_a },
  -> { FPost.includes(:writer).where(f_writers: {name: "Z"}).to_a },
  -> { FPost.select("id, 9 AS extra").where(status: :live).readonly.strict_loading.to_a },
  -> { [FConstrainedPost.find_by!(writer_id: 2, id: 4).reload] }])

checked = 0
cases.each_with_index do |call, index|
  off = snapshot(call, false, events)
  on = snapshot(call, true, events)
  raise "case #{index} differs:\n#{off.inspect}\n#{on.inspect}" unless off == on
  checked += 1
end

# Query-cache hits and skipped cache share Rails' cache/instrumentation path.
ActiveRecord::Base.cache do
  [false, true].each do |skip|
    call = -> { FPost.where(writer_id: 2).skip_query_cache!(skip).to_a }
    snapshot(call, false, events)
    off = snapshot(call, false, events)
    on = snapshot(call, true, events)
    raise "query cache differs" unless off == on
    checked += 1
  end
end
FPost.connection.unprepared_statement do
  call = -> { FPost.where(writer_id: 2).to_a }
  raise "unprepared differs" unless snapshot(call, false, events) == snapshot(call, true, events)
  checked += 1
end

site = ARCallsite::DirectSite.new(FPost, arity: 2) do |writer, state|
  FPost.where(writer_id: writer, status: state).ordered.limit(3).includes(:writer)
end
[[1, :draft], [2, :live], [99, :live], [1, nil], [nil, :draft], [2, :draft]].each do |values|
  call = -> { site.call(*values) }
  raise "direct site differs for #{values.inspect}" unless snapshot(call, false, events) == snapshot(call, true, events)
  checked += 1
end

# A new scope/type recipe must not leave a captured owner/status behind.
FPost.send(:default_scope, -> { where.not(id: 4) })
FPost.reset_column_information
cases.first(12).each do |call|
  raise "mutated schema/default differs" unless snapshot(call, false, events) == snapshot(call, true, events)
  checked += 1
end

Dir.mktmpdir("ar-callsite-") do |directory|
  FPost.establish_connection(adapter: "sqlite3", database: File.join(directory, "second.sqlite3"))
  connection = FPost.connection
  connection.execute("CREATE TABLE f_posts (id INTEGER PRIMARY KEY, writer_id INTEGER, type TEXT, status INTEGER, title TEXT, payload TEXT)")
  connection.execute("INSERT INTO f_posts VALUES (1, 2, NULL, 1, 'SECOND-DATABASE', NULL)")
  FPost.reset_column_information
  call = -> { FPost.where(writer_id: 2).to_a }
  off = snapshot(call, false, events)
  on = snapshot(call, true, events)
  raise "connection switch captured old rows" unless off == on && on[0][0][1]["title"] == "SECOND-DATABASE"
  checked += 1
  FPost.remove_connection
  FPost.reset_column_information
end

class FCustomString < ActiveRecord::Type::String
  def serialize(value) = super(value&.downcase)
end
FPost.attribute(:title, FCustomString.new)
call = -> { FPost.where(title: "Z").to_a }
raise "custom type differs" unless snapshot(call, false, events) == snapshot(call, true, events)
checked += 1

raise "vacuous" unless ARCallsite.counts["queries"] > 0 && ARCallsite.counts["rows"] > 0 &&
  ARCallsite.counts["shadow_checks"] == ARCallsite.counts["queries"]
puts JSON.pretty_generate(cases: checked, counts: ARCallsite.counts, refusals: ARCallsite.refusals,
  cached_plans: ARCallsite.plans.size, database_rows: FPost.unscoped.order(:id).pluck(:id, :title))
