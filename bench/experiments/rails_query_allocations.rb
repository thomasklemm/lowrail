# frozen_string_literal: true

# Standalone query construction, not an HTTP benchmark or app modification.
# FIZZY_SCHEMA=/path/to/fizzy/db/schema.rb ruby --yjit rails_query_allocations.rb profile
require "active_record"
require "json"
require "digest"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
schema = File.realpath(ENV.fetch("FIZZY_SCHEMA"))
load schema

class Account < ActiveRecord::Base
  has_many :users
  has_many :tags
end
class User < ActiveRecord::Base
  belongs_to :account
  has_many :accesses
  has_many :buckets, through: :accesses
  has_many :filters, foreign_key: :creator_id
  enum :role, %i[member system].index_by(&:itself), scopes: false
  scope :without_system, -> { where.not(role: :system) }
  scope :active, -> { without_system.where(active: true) }
end
class Access < ActiveRecord::Base
  belongs_to :bucket
  belongs_to :user
end
class Bucket < ActiveRecord::Base
  belongs_to :account
  has_many :accesses
  has_many :users, through: :accesses
  has_many :bubbles
end
class Filter < ActiveRecord::Base; end
class Bubble < ActiveRecord::Base
  belongs_to :bucket
  belongs_to :creator, class_name: "User"
  has_one :pop
  has_many :assignments
  has_many :messages, -> { chronologically }
  enum :status, %w[creating drafted published].index_by(&:itself)
  scope :active, -> { where.missing(:pop) }
  scope :published_or_drafted_by, ->(user) { where(status: :published).or(where(status: :drafted, creator: user)) }
  scope :ordered_by_activity, -> { order activity_score_order: :desc }
end
class Pop < ActiveRecord::Base
  belongs_to :bubble
end
class Assignment < ActiveRecord::Base
  belongs_to :bubble
  belongs_to :assignee, class_name: "User"
end
class Message < ActiveRecord::Base
  belongs_to :bubble
  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :comments, -> { where(messageable_type: "Comment") }
end
class Tag < ActiveRecord::Base; end

if ENV["VARIANT"] == "empty_clauses"
  class ActiveRecord::Relation::Merger
    private
      def merge_clauses
        relation.from_clause = other.from_clause if replace_from_clause?

        unless relation.where_clause.empty? && other.where_clause.empty?
          where_clause = relation.where_clause.merge(other.where_clause)
          relation.where_clause = where_clause unless where_clause.empty?
        end

        unless relation.having_clause.empty? && other.having_clause.empty?
          having_clause = relation.having_clause.merge(other.having_clause)
          relation.having_clause = having_clause unless having_clause.empty?
        end
      end
  end
end

Account.insert_all!([{ id: 3, name: "First" }, { id: 4, name: "Other" }])
User.insert_all!([
  { id: 11, account_id: 3, name: "Member", active: true, role: "member" },
  { id: 12, account_id: 3, name: "Inactive", active: false, role: "member" },
  { id: 13, account_id: 3, name: "System", active: true, role: "system" },
  { id: 14, account_id: 4, name: "Other", active: true, role: "member" }
])
Bucket.insert_all!([
  { id: 23, account_id: 3, creator_id: 11, name: "First" },
  { id: 24, account_id: 4, creator_id: 14, name: "Other" }
])
Access.insert_all!([11, 12, 13].map { |id| { bucket_id: 23, user_id: id } } + [{ bucket_id: 24, user_id: 14 }])
Bubble.insert_all!([
  { id: 37, bucket_id: 23, creator_id: 11, status: "published", activity_score_order: 9.0 },
  { id: 38, bucket_id: 23, creator_id: 11, status: "drafted", activity_score_order: 7.0 },
  { id: 39, bucket_id: 23, creator_id: 14, status: "drafted", activity_score_order: 10.0 },
  { id: 40, bucket_id: 23, creator_id: 11, status: "published", activity_score_order: 5.0 },
  { id: 41, bucket_id: 24, creator_id: 14, status: "published", activity_score_order: 20.0 }
].map { _1.merge(auto_pop_at: Time.utc(2027)) })
Pop.create!(bubble_id: 40, user_id: 11)
Assignment.create!(bubble_id: 37, assignee_id: 11, assigner_id: 14)
Message.insert_all!([
  { id: 51, bubble_id: 37, messageable_type: "Comment", messageable_id: 1 },
  { id: 52, bubble_id: 37, messageable_type: "EventSummary", messageable_id: 2 },
  { id: 53, bubble_id: 41, messageable_type: "Comment", messageable_id: 3 }
].map { _1.merge(created_at: Time.utc(2026), updated_at: Time.utc(2026)) })

USER = User.find(11)
BUCKET = Bucket.find(23)
BUBBLE = Bubble.find(37)

# Repeated calls reuse the same association proxy, as templates do. Only its
# cached base scope is reused, never a built query's Arel or SQL.
QUERIES = {
  buckets_access: -> { USER.buckets.all },
  buckets_filters: -> { USER.filters.all },
  buckets_cards: -> { BUCKET.bubbles.active.published_or_drafted_by(USER).ordered_by_activity.limit(10) },
  card_bucket: -> { USER.buckets.where(id: 23).limit(1) },
  card_record: -> { BUCKET.bubbles.where(id: 37).limit(1) },
  card_users: -> { BUCKET.users.active },
  card_assignment: -> { BUBBLE.assignments.where(assignee: USER).select(Arel.sql("1 AS one")).limit(1) },
  card_messages: -> { BUBBLE.messages.all },
  card_comments: -> { BUBBLE.messages.comments }
}.freeze

expected = { buckets_access: [23], buckets_cards: [37, 38], card_bucket: [23],
  card_record: [37], card_users: [11], card_messages: [52, 51], card_comments: [51] }
expected.each do |name, ids|
  raise "#{name} rows" unless QUERIES.fetch(name).call.map(&:id) == ids
end
raise "assignment" unless ActiveRecord::Base.connection.select_rows(QUERIES.fetch(:card_assignment).call.to_sql) == [[1]]
all_ids = [11, 12, 13, 14]
raise "empty merge" unless User.all.merge(User.all).order(:id).ids == all_ids
raise "left predicate" unless User.where(id: 11).merge(User.all).ids == [11]
raise "right predicate" unless User.all.merge(User.where(id: 12)).ids == [12]
raise "override" unless User.where(id: 11).merge(User.where(id: 12)).ids == [12]
raise "none" unless User.none.merge(User.all).ids == []
duplicate = User.where("users.id = 11").where("users.id = 11").merge(User.all)
raise "duplicate predicates" unless duplicate.to_sql.scan("users.id = 11").size == 1 && duplicate.ids == [11]
raise "having" unless User.group(:account_id).having("COUNT(*) > 1").merge(User.all).count == { 3 => 3 }
base = User.all
base.merge(User.all).where!(id: 11)
raise "branch mutation" unless base.order(:id).ids == all_ids

# These are query-building reproductions, not find/exists? statement-cache or
# database-execution measurements. A separate build+arel cohort includes joins.
QUERIES.each_value { |query| 100.times { query.call.arel } }
mode = ARGV.fetch(0, "profile")
rails_source = File.dirname(ActiveRecord::Base.method(:establish_connection).source_location.first)
metadata = { ruby: RUBY_DESCRIPTION, rails: ActiveRecord.version.to_s,
  rails_revision: IO.popen(["git", "-C", rails_source, "rev-parse", "HEAD"], &:read).strip,
  schema_sha256: Digest::SHA256.file(schema).hexdigest, variant: ENV.fetch("VARIANT", "main"),
  script_sha256: Digest::SHA256.file(__FILE__).hexdigest,
  yjit: RubyVM::YJIT.enabled?, zjit: RubyVM::ZJIT.enabled?,
  contracts: "asymmetric executed query and merge checks passed",
  sql: QUERIES.transform_values { _1.call.to_sql } }

if mode == "profile"
  require "stackprof"
  profiles = {}
  QUERIES.each do |name, query|
    %i[build arel].each do |stage|
      iterations = 500
      GC.start
      before = GC.stat(:total_allocated_objects)
      data = StackProf.run(mode: :object, interval: 1) do
        iterations.times do
          relation = query.call
          relation.arel if stage == :arel
        end
      end
      allocated = GC.stat(:total_allocated_objects) - before
      profiles["#{name}/#{stage}"] = { iterations: iterations,
        allocated: allocated, profile: data }
    end
  end
  puts JSON.generate(metadata.merge(profiles: profiles))
elsif mode == "trace"
  require "objspace"
  profiles = {}
  QUERIES.each do |name, query|
    %i[build arel].each do |stage|
      iterations = 100
      GC.start
      GC.disable
      ObjectSpace.trace_object_allocations_clear
      ObjectSpace.trace_object_allocations_start
      iterations.times do
        relation = query.call
        relation.arel if stage == :arel
      end
      ObjectSpace.trace_object_allocations_stop
      sites = Hash.new(0)
      ObjectSpace.each_object do |object|
        path = ObjectSpace.allocation_sourcefile(object)
        next unless path
        sites[[path, ObjectSpace.allocation_sourceline(object)]] += 1
      end
      profiles["#{name}/#{stage}"] = { iterations: iterations,
        sites: sites.sort_by { |_, count| -count }.map { |(file, line), count| { file: file, line: line, count: count } } }
      GC.enable
    end
  end
  puts JSON.generate(metadata.merge(profiles: profiles))
elsif mode == "bench"
  runners = QUERIES.flat_map do |name, query|
    [["#{name}/build", -> { query.call }], ["#{name}/arel", -> { query.call.arel }]]
  end.to_h
  results = runners.to_h { |name, _| [name, []] }
  runners.each_value { |runner| 2_000.times { runner.call } }
  5.times do |round|
    runners.keys.rotate(round * 3).each do |name|
      runner = runners.fetch(name)
      iterations = 5_000
      GC.start
      before = GC.stat(:total_allocated_objects)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      iterations.times { runner.call }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      allocated = GC.stat(:total_allocated_objects) - before
      results[name] << { ips: iterations / elapsed, elapsed: elapsed, allocations: allocated, iterations: iterations }
    end
  end
  puts JSON.pretty_generate(metadata.merge(results: results))
else
  abort "profile, trace or bench required"
end
