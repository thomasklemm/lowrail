# frozen_string_literal: true

require_relative "test_helper"

class ARPlansTest < Minitest::Test
  include LowrailTest

  SCENARIO = <<~'RUBY'
    gem "activerecord", "~> 8.1.4"
    require "active_record"
    require "lowrail"
    require "lowrail/manifest"
    require "lowrail/stats"
    require "lowrail/ar_plan_build"
    require "lowrail/ar_guard"
    module Rails
      def self.version = ActiveRecord::VERSION::STRING
    end
    Lowrail::AR.install
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table(:writers) { |t| t.string :name }
      create_table(:posts) { |t| t.integer :writer_id; t.string :title; t.boolean :published }
    end
    class Writer < ActiveRecord::Base
      has_many :posts, inverse_of: :writer
      has_many :preferred_posts, -> { where(published: true).order(:title).limit(2).includes(:writer) }, class_name: "Post", inverse_of: :writer
      has_many :dynamic_posts, -> { where(title: Thread.current[:title]) }, class_name: "Post"
      has_many :clock_posts, -> { where(title: Time.current.to_s) }, class_name: "Post"
      has_many :negative_posts, -> { where.not(published: true) }, class_name: "Post"
    end
    class Post < ActiveRecord::Base
      belongs_to :writer, inverse_of: :posts
    end
    a = Writer.create!(name: "a")
    b = Writer.create!(name: "b")
    [[a, "z", true], [a, "a", true], [a, "hidden", false], [b, "foreign", true]].each do |writer, title, published|
      Post.create!(writer: writer, title: title, published: published)
    end
    dir = ARGV.fetch(0)
    data = { "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
      "files" => {}, "units" => [] }
    Lowrail.write_json(File.join(dir, "manifest.json"), data)
    Lowrail.write_json(File.join(dir, "ledger.json"), [])
    Lowrail::ARPlanBuild.run(dir)
    manifest = Lowrail::Manifest.load(File.join(dir, "manifest.json"))
    raise File.read(File.join(dir, "ledger.json")) if manifest.units.empty?
    Lowrail::Stats.enable!
    require "lowrail/guard"
    Lowrail::Guard.install(manifest, Lowrail::Stats::STATE)
    if ENV["LOWRAIL"] == "1"
      Lowrail::ARPlans.install(manifest)
      Lowrail::ARPlans.activate
    end
    result = {}
    events = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA"
      events << [payload[:name], payload[:sql], payload[:binds].map { [_1.name, _1.value_before_type_cast, _1.type.class.name, _1.value_for_database] }, !!payload[:cached]]
    end
    read = ->(writer) {
      # A CollectionProxy memoizes its scope even without Lowrail. A fresh
      # owner exercises new current/default scopes rather than that old scope.
      writer = Writer.find(writer.id)
      writer.preferred_posts.map { [_1.title, _1.writer.equal?(writer), _1.strict_loading?] }
    }
    result["owners"] = [read.call(a), read.call(b), read.call(a)]
    result["hits_before_changes"] = Lowrail::Stats.unit_hits.values.sum
    # Query-cache flags and bind types/values must agree, not only row IDs.
    ActiveRecord::Base.cache do
      Post.connection_pool.with_connection(&:clear_query_cache)
      result["cached"] = [read.call(a), read.call(a)]
    end
    Post.where(title: "z").scoping(all_queries: true) { result["scoped"] = read.call(a) }
    Post.unscoped { result["unscoped"] = read.call(a) }
    # The public lazy relation is not replaced with an Array or shared prototype.
    lazy = a.preferred_posts.where(title: "z")
    result["lazy"] = [lazy.is_a?(ActiveRecord::Relation), !!lazy.loaded?, lazy.map(&:title)]
    Thread.current[:title] = "z"
    result["dynamic"] = a.dynamic_posts.map(&:title)
    Thread.current[:title] = "a"
    result["dynamic_changed"] = Writer.find(a.id).dynamic_posts.map(&:title)
    result["strict"] = begin
      fresh = Writer.find(a.id)
      fresh.strict_loading!
      fresh.preferred_posts.to_a
      "no error"
    rescue => e
      e.class.name
    end
    # Each mutation starts in a fresh process with a warm fast path, so one
    # invalidation cannot mask a broken guard for a later mutation.
    case ENV.fetch("CHANGE")
    when "method"
      rel = a.association(:preferred_posts).scope.class
      rel.define_method(:build_arel) { |*args| super(*args).tap { _1.where(Post.arel_table[:title].eq("z")) } }
    when "default_scope"
      Post.send(:default_scope, -> { where(title: "z") })
    when "column"
      Post.connection_pool.with_connection { _1.change_column(:posts, :published, :integer) }
      Post.reset_column_information
    when "annotations"
      ActiveRecord.query_transformers = [->(sql, *) { sql + " /* live annotation */" }]
    end
    result["changed"] = read.call(a)
    ActiveSupport::Notifications.unsubscribe(subscription)
    ledger = JSON.parse(File.read(File.join(dir, "ledger.json")))
    result["ledger"] = ledger.map { [_1["method"], _1["outcome"]] }
    result["events"] = events
    puts JSON.generate(result)
  RUBY

  def test_scoped_reader_preserves_rows_events_and_runtime_changes
    skip "Rails unavailable" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      file = File.join(dir, "scenario.rb")
      File.write(file, SCENARIO)
      %w[method default_scope column annotations].each do |change|
        outputs = %w[0 1].map do |mode|
          out, err, status = ruby(file, dir, setup: false, env: { "LOWRAIL" => mode, "CHANGE" => change, "LOWRAIL_DEBUG" => "1", "RUBYLIB" => LowrailTest::GEM_LIB })
          assert status.success?, "#{change}: #{err}\n#{out}"
          JSON.parse(out.lines.last)
        end
        off, on = outputs
        assert_equal 0, off.delete("hits_before_changes")
        assert_operator on.delete("hits_before_changes"), :>, 0
        assert_equal off, on, change
        assert_equal [["a", true, false], ["z", true, false]], on.fetch("owners").first
        assert_equal [["foreign", true, false]], on.fetch("owners")[1]
        assert_equal [["z", true, false]], on.fetch("scoped")
        assert_equal [true, false, ["z"]], on.fetch("lazy")
        assert_equal ["a"], on.fetch("dynamic_changed")
        assert_equal "ActiveRecord::StrictLoadingViolationError", on.fetch("strict")
        assert_equal [["z", true, false]], on.fetch("changed") if %w[method default_scope].include?(change)
        assert on.fetch("events").any? { _1.last == true }, "query cache was not exercised"
        %w[dynamic clock negative].each do |name|
          assert on.fetch("ledger").any? { |label, reason| label == "Writer##{name}_posts" && reason.include?("dynamic") }
        end
      end
    end
  end
end
