# frozen_string_literal: true

require_relative "test_helper"

class PreloadPlansTest < Minitest::Test
  include LowrailTest

  # Real Rails/SQLite, through the public Preloader interface. No mocks of
  # loader internals: the same asymmetric workload must agree on both paths.
  SCENARIO = <<~'RUBY'
    gem "activerecord", "~> 8.1.4"
    require "active_record"
    require "lowrail"
    require "lowrail/manifest"
    require "lowrail/preload_build"
    module Rails
      def self.version = ActiveRecord::VERSION::STRING
    end
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.define do
      create_table(:writers) { |t| t.string :name }
      create_table(:posts) { |t| t.integer :writer_id; t.integer :alternate_id; t.string :title }
      create_table(:notes) { |t| t.integer :post_id; t.string :body }
      create_table(:poly_posts) { |t| t.integer :owner_id; t.string :owner_type }
    end
    class Writer < ActiveRecord::Base
      has_many :posts, inverse_of: :writer
      has_many :other_posts, class_name: "Post", foreign_key: :writer_id
      has_many :peers, class_name: "Writer", foreign_key: :id, inverse_of: false
      has_many :notes, through: :posts
      has_many :filtered, -> { where(title: Thread.current[:title]) }, class_name: "Post"
      has_many :dependent_posts, ->(writer) { where(title: writer.name) }, class_name: "Post"
      has_many :custom_posts, class_name: "CustomPost", foreign_key: :writer_id
      has_many :reflection_posts, class_name: "Post", foreign_key: :writer_id
      has_many :poly_posts, as: :owner
      has_many :native_poly_posts, class_name: "NativePolyPost", as: :owner
    end
    class Post < ActiveRecord::Base
      belongs_to :writer, inverse_of: :posts
      has_many :notes, inverse_of: :post
      after_find do
        if Thread.current[:mutate_scope]
          Note.send(:default_scope, -> { where(body: "x2") })
          NativePolyPost.send(:default_scope, -> { where(owner_id: -1) })
        end
      end
    end
    class Note < ActiveRecord::Base
      belongs_to :post, inverse_of: :notes
    end
    class DynamicString < ActiveRecord::Type::String
      def serialize(value) = Thread.current[:change_type] ? "changed" : super
    end
    class PolyPost < ActiveRecord::Base
      belongs_to :owner, polymorphic: true
      attribute :owner_type, DynamicString.new
    end
    class NativePolyPost < ActiveRecord::Base
      self.table_name = "poly_posts"
    end
    class CustomPost < ActiveRecord::Base
      self.table_name = "posts"
      def self.scope_for_association(*) = super.where(title: Thread.current[:title])
    end
    Writer.reflect_on_association(:reflection_posts).define_singleton_method(:join_scopes) do |*args|
      super(*args) + [klass.where(title: Thread.current[:title])]
    end
    if ENV["PRELOAD_PATCH"] == "batch"
      module CustomBatch
        def call
          $build_wrapper_calls = ($build_wrapper_calls || 0) + 1
          super
        end
      end
      ActiveRecord::Associations::Preloader::Batch.prepend(CustomBatch)
    elsif ENV["PRELOAD_PATCH"] == "association"
      module CustomAssociation
        def association(name)
          $build_wrapper_calls = ($build_wrapper_calls || 0) + 1
          super
        end
      end
      Writer.prepend(CustomAssociation)
    end
    a = Writer.create!(name: "A")
    b = Writer.create!(name: "B")
    x = a.posts.create!(title: "first", alternate_id: b.id)
    y = a.posts.create!(title: "second")
    z = b.posts.create!(title: "third", alternate_id: a.id)
    x.notes.create!(body: "x1"); x.notes.create!(body: "x2"); z.notes.create!(body: "z1")
    PolyPost.create!(owner: a)
    dir = Dir.pwd
    File.write("manifest.json", JSON.generate({format: 1, ruby_description: RUBY_DESCRIPTION,
      compile_option: Lowrail::Manifest.compile_option_fingerprint, files: {}, units: [{id: 7, facts: []}]}))
    File.write("ledger.json", "[]")
    built = Lowrail::PreloadBuild.build
    built[:units].each_with_index { |unit, i| unit["id"] = 8 + i }
    data = JSON.parse(File.read("manifest.json"))
    data["units"].concat(built[:units])
    File.write("manifest.json", JSON.generate(data))
    File.write("ledger.json", JSON.generate(built[:ledger]))
    if ENV["STALE_PRELOAD_SOURCE"]
      data = JSON.parse(File.read("manifest.json"))
      data["units"].last["preload_facts"]["sources"].transform_values! { "stale" }
      File.write("manifest.json", JSON.generate(data))
    end
    Lowrail.boot(root: dir)
    Lowrail.setup(root: dir, dir: dir) if ENV["LOWRAIL"] == "1"
    ActiveSupport.run_load_hooks(:after_initialize)
    result = { "unit_ids" => JSON.parse(File.read("manifest.json"))["units"].map { _1["id"] } }
    preload = ->(rows, spec, **opts) { ActiveRecord::Associations::Preloader.new(records: rows, associations: spec, **opts).call }
    signature = ->(rows) { rows.map { |r| [r.name, r.association(:posts).loaded?, r.posts.map { |p| [p.title, p.association(:notes).loaded?, p.notes.map(&:body), p.writer.equal?(r)] }] } }
    rows = [Writer.find(b.id), Writer.find(a.id), Writer.find(a.id)]
    result["root_loaders"] = preload.call(rows, { posts: :notes }).size
    result["nested"] = signature.call(rows)
    result["available_false"] = preload.call([Writer.find(a.id)], :posts, available_records: false).size
    custom_available = Object.new
    def custom_available.flatten = []
    result["available_custom"] = preload.call([Writer.find(a.id)], :posts, available_records: custom_available).size
    result["associate_flag"] = ActiveRecord::Associations::Preloader.new(records: [Writer.find(a.id)],
      associations: :posts, associate_by_default: "truthy").associate_by_default
    rows = [Writer.find(a.id)]
    preload.call(rows, { "posts" => :notes, posts: :writer })
    result["distinct_spec_keys"] = rows.first.posts.map { [_1.association(:notes).loaded?, _1.association(:writer).loaded?] }
    identity_spec = {}.compare_by_identity
    identity_spec[+"posts"] = :notes
    identity_spec[+"posts"] = :writer
    rows = [Writer.find(a.id)]
    identity_roots = preload.call(rows, identity_spec)
    result["identity_spec"] = [identity_roots.size, rows.first.posts.map { [_1.association(:notes).loaded?, _1.association(:writer).loaded?] }]
    # Already loaded associations and unsaved collection targets survive.
    rows = [Writer.find(a.id), Writer.find(b.id)]
    rows.first.posts.load
    rows.last.posts.build(title: "unsaved")
    preload.call(rows, :posts)
    result["loaded_unsaved"] = rows.map { _1.posts.map(&:title) }
    # A subsequent preload must see a new row: the cache holds no data.
    a.posts.create!(title: "new")
    rows = [Writer.find(a.id)]
    preload.call(rows, :posts)
    result["fresh"] = rows.first.posts.map(&:title)
    # The returned Rails loader exposes #scope. Loading or mutating that
    # per-call relation must never expose or change a cached prototype.
    returned = preload.call([Writer.find(a.id)], :posts)
    returned.first.scope.where!(title: "first").load
    rows = [Writer.find(a.id)]
    preload.call(rows, :posts)
    result["private_scope"] = rows.first.posts.map(&:title)
    rows = [Writer.find(a.id)]
    inspected = ActiveRecord::Associations::Preloader.new(records: rows, associations: :posts)
    inspected.loaders.first.scope.where!(title: "second")
    inspected.call
    result["inspected_scope"] = rows.first.posts.map(&:title)
    rows = [Writer.find(a.id)]
    repeated = ActiveRecord::Associations::Preloader.new(records: rows, associations: :posts)
    first = repeated.call
    rows.first.association(:posts).reset
    again = repeated.call
    result["repeat_call"] = [first.zip(again).all? { |x, y| x.equal?(y) }, rows.first.association(:posts).loaded?]
    first.clear
    repeated.loaders.clear
    result["return_container"] = repeated.call.size
    inspected = ActiveRecord::Associations::Preloader.new(records: [Writer.find(a.id)], associations: { posts: :notes })
    roots = inspected.call
    result["branch_state"] = [inspected.branches.all?(&:done?),
      inspected.branches.flat_map(&:loaders).zip(roots).all? { |x, y| x.equal?(y) },
      inspected.branches.first.children.all?(&:done?)]
    inspected.branches.clear
    result["branch_mutation"] = inspected.call.size
    rows = [Writer.find(a.id), Writer.find(b.id)]
    queries = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") { |*args| queries << args.last[:sql] if args.last[:sql].start_with?("SELECT") }
    preload.call(rows, [:posts, :other_posts])
    ActiveSupport::Notifications.unsubscribe(subscription)
    result["grouped_queries"] = queries.size
    result["aliases"] = rows.map { [_1.posts.map(&:title), _1.other_posts.map(&:title)] }
    # Repeating a class inside its own branch must not postpone that branch
    # behind unrelated tables. SQL order is observable by after_find hooks.
    rows = [Writer.find(a.id)]
    queries = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") { |*args| queries << args.last[:sql][/FROM "(\w+)"/, 1] if args.last[:sql].start_with?("SELECT") }
    preload.call(rows, { peers: :peers, posts: nil })
    ActiveSupport::Notifications.unsubscribe(subscription)
    result["scheduling_queries"] = queries
    result["hash_order"] = [{ peers: nil, posts: nil }, { posts: nil, peers: nil }].map do |spec|
      preload.call([Writer.find(a.id)], spec).map { _1.klass.name }
    end
    custom_name = Class.new(String) { def to_sym = :peers }.new("posts")
    result["custom_name"] = preload.call([Writer.find(a.id)], custom_name).map { _1.klass.name }
    empty = Writer.create!(name: "empty")
    # Cross-branch table dependencies use Rails, including repeated calls and
    # branches pruned by absent rows. Only a fallback marker may be retained.
    result["dependent_schedule"] = 2.times.map do
      rows = [Writer.find(empty.id), Writer.find(a.id)]
      preload.call(rows, { peers: :posts, posts: :writer })
      rows.map { |r| [r.peers.map { |p| [p.name, p.association(:posts).loaded?, p.posts.map(&:title)] },
        r.posts.map { |p| [p.title, p.association(:writer).loaded?, p.writer.name] }] }
    end
    rows = [Writer.find(a.id)]
    Thread.current[:mutate_scope] = true
    preload.call(rows, { posts: :notes, native_poly_posts: nil })
    Thread.current[:mutate_scope] = nil
    result["callback_scope"] = [rows.first.posts.map { _1.notes.map(&:body) }, rows.first.native_poly_posts.size]
    Note.default_scopes = []
    NativePolyPost.default_scopes = []
    result["dynamic_type"] = [false, true].map do |change|
      Thread.current[:change_type] = change
      rows = [Writer.find(a.id)]
      preload.call(rows, :poly_posts)
      rows.first.poly_posts.size
    end
    Thread.current[:change_type] = nil
    Post.where(title: "second").scoping do
      rows = [Writer.find(a.id)]
      preload.call(rows, :posts)
      result["current_scope"] = rows.first.posts.map(&:title)
    end
    Thread.current[:title] = "second"
    rows = [Writer.find(a.id)]
    preload.call(rows, :filtered)
    result["dynamic"] = rows.first.filtered.map(&:title)
    preload.call(rows, :custom_posts)
    result["custom_constructor"] = rows.first.custom_posts.map(&:title)
    preload.call(rows, :reflection_posts)
    result["reflection_constructor"] = rows.first.reflection_posts.map(&:title)
    Thread.current[:title] = "new"
    rows = [Writer.find(a.id)]
    preload.call(rows, :filtered)
    result["dynamic_next"] = rows.first.filtered.map(&:title)
    preload.call(rows, :custom_posts)
    result["custom_constructor_next"] = rows.first.custom_posts.map(&:title)
    preload.call(rows, :reflection_posts)
    result["reflection_constructor_next"] = rows.first.reflection_posts.map(&:title)
    rows = [Writer.find(a.id)]
    preload.call(rows, :notes)
    result["through"] = rows.first.notes.map(&:body)
    # An initialized preloader must recheck guards before it loads anything.
    rows = [Writer.find(a.id)]
    spec = { posts: :notes }
    pending = ActiveRecord::Associations::Preloader.new(records: rows, associations: spec)
    spec[:posts] = :writer
    Post.define_singleton_method(:scope_for_association) { |*| where(title: "second") }
    pending.call
    result["method_change"] = rows.first.posts.map(&:title)
    result["snapshot_spec"] = rows.first.posts.map { _1.association(:notes).loaded? }
    Post.singleton_class.remove_method(:scope_for_association)
    rows = [Writer.find(a.id)]
    preload.call(rows, :posts)
    result["restored"] = rows.first.posts.map(&:title)
    change = Module.new { define_method(:scope_for_association) { |*| where(title: "first") } }
    Post.singleton_class.prepend(change)
    rows = [Writer.find(a.id)]
    preload.call(rows, :posts)
    result["module_change"] = rows.first.posts.map(&:title)
    change.remove_method(:scope_for_association)
    Post.reset_column_information
    rows = [Writer.find(b.id)]
    preload.call(rows, :posts)
    result["schema_reset"] = rows.first.posts.map(&:title)
    Post.send(:default_scope, -> { where(title: "second") })
    rows = [Writer.find(a.id)]
    preload.call(rows, :posts)
    result["default_scope"] = rows.first.posts.map(&:title)
    Post.default_scopes = []
    Writer.has_many :posts, class_name: "Post", foreign_key: :alternate_id
    rows = [Writer.find(a.id)]
    preload.call(rows, :posts)
    result["reflection_change"] = rows.first.posts.map(&:title)
    preload.call([Writer.find(a.id)], :other_posts)
    old_post = Post
    Object.send(:remove_const, :Post)
    Object.const_set(:Post, Class.new(ActiveRecord::Base))
    Post.table_name = "posts"
    Post.unscoped # Generate the replacement's model-specific Relation class.
    old_post.define_singleton_method(:scope_for_association) { |*| unscoped.where(title: "second") }
    rows = [Writer.find(a.id)]
    preload.call(rows, :other_posts)
    result["reloaded_target"] = rows.first.other_posts.map(&:title)
    old_post.singleton_class.remove_method(:scope_for_association)
    Object.send(:remove_const, :Post)
    Object.const_set(:Post, old_post)
    preload.call([Writer.find(a.id)], :native_poly_posts)
    type = ActiveModel::Type::String
    original = type.instance_method(:serialize)
    type.define_method(:serialize) { |value| value == "Writer" ? "changed" : original.bind_call(self, value) }
    rows = [Writer.find(a.id)]
    preload.call(rows, :native_poly_posts)
    result["type_method_change"] = rows.first.native_poly_posts.size
    type.remove_method(:serialize)
    # A superclass definition can change without changing the resolved
    # String#serialize method. The serialized constant must not stay cached.
    type = ActiveModel::Type::Value
    original = type.instance_method(:serialize)
    type.define_method(:serialize) { |value| value == "Writer" ? "changed" : original.bind_call(self, value) }
    rows = [Writer.find(a.id)]
    preload.call(rows, :native_poly_posts)
    result["type_super_change"] = rows.first.native_poly_posts.size
    type.define_method(:serialize, original)
    $batch_calls = 0
    ActiveRecord::Associations::Preloader::Batch.prepend(Module.new do
      def call
        $batch_calls += 1
        super
      end
    end)
    preload.call([Writer.find(a.id)], :other_posts)
    result["batch_change"] = $batch_calls
    result["build_wrapper_calls"] = $build_wrapper_calls if ENV["PRELOAD_PATCH"]
    result["hits"] = defined?(Lowrail::Stats) ? Lowrail::Stats.unit_hits : {}
    puts JSON.generate(result)
  RUBY

  def test_plans_keep_rails_results_and_invalidate
    realpath_tmpdir do |dir|
      File.write(File.join(dir, "scenario.rb"), SCENARIO)
      runs = [["0", nil, nil], ["1", nil, nil], ["1", "", nil], ["1", nil, "1"]].map do |mode, units, stale|
        out, err, status = ruby(File.join(dir, "scenario.rb"), setup: false, chdir: dir,
          env: { "RUBYOPT" => "-I#{GEM_LIB}", "LOWRAIL" => mode, "LOWRAIL_UNITS" => units,
            "STALE_PRELOAD_SOURCE" => stale,
            "LOWRAIL_STATS" => File.join(dir, "stats-#{mode}") })
        skip "install activerecord 8.1.4 and sqlite3 to run preload integration tests" if err.include?("Could not find 'activerecord'")
        assert status.success?, "#{err}\n#{out}"
        JSON.parse(out.lines.last)
      end
      off, on, disabled, stale = runs
      assert_operator on.delete("hits").fetch("8", 0), :>=, 6
      assert_empty off.delete("hits")
      assert_empty disabled.delete("hits")
      assert_empty stale.delete("hits")
      assert_equal off, on
      assert_equal off, disabled
      assert_equal off, stale
      assert_equal [7, 8], on["unit_ids"]
      assert_equal 1, on["root_loaders"]
      assert_equal 1, on["available_false"]
      assert_equal 1, on["available_custom"]
      assert_equal "truthy", on["associate_flag"]
      assert_equal [[true, true], [true, true]], on["distinct_spec_keys"]
      assert_equal [2, [[true, true], [true, true]]], on["identity_spec"]
      assert_equal [true], on["snapshot_spec"]
      assert_equal ["third", "unsaved"], on["loaded_unsaved"].last
      assert_equal ["first", "second", "new"], on["fresh"]
      assert_equal ["first", "second", "new"], on["private_scope"]
      assert_equal ["second"], on["inspected_scope"]
      assert_equal [true, false], on["repeat_call"]
      assert_equal 1, on["return_container"]
      assert_equal [true, true, true], on["branch_state"]
      assert_equal 0, on["branch_mutation"]
      assert_equal 1, on["grouped_queries"]
      assert_equal %w[writers posts writers], on["scheduling_queries"]
      assert_equal [%w[Writer Post], %w[Post Writer]], on["hash_order"]
      assert_equal ["Writer"], on["custom_name"]
      assert_equal [[["x2"], [], []], 1], on["callback_scope"]
      assert_equal [1, 0], on["dynamic_type"]
      assert_equal 0, on["type_method_change"]
      assert_equal 0, on["type_super_change"]
      assert_equal ["first", "second", "new"], on["current_scope"]
      %w[dynamic method_change default_scope].each { assert_equal ["second"], on[_1], _1 }
      assert_equal ["second"], on["custom_constructor"]
      assert_equal ["new"], on["custom_constructor_next"]
      assert_equal ["second"], on["reflection_constructor"]
      assert_equal ["new"], on["reflection_constructor_next"]
      assert_equal ["new"], on["dynamic_next"]
      assert_equal ["first"], on["module_change"]
      assert_equal ["third"], on["schema_reset"]
      assert_equal ["third"], on["reflection_change"]
      assert_equal ["second"], on["reloaded_target"]
      assert_equal 1, on["batch_change"]
      assert_equal ["x1", "x2"], on["through"]
    end
  end

  def test_preexisting_preloader_wrappers_are_not_bypassed
    realpath_tmpdir do |dir|
      File.write(File.join(dir, "scenario.rb"), SCENARIO)
      %w[batch association].each do |patch|
        runs = %w[0 1].map do |mode|
          out, err, status = ruby(File.join(dir, "scenario.rb"), setup: false, chdir: dir,
            env: { "RUBYOPT" => "-I#{GEM_LIB}", "LOWRAIL" => mode, "PRELOAD_PATCH" => patch,
              "LOWRAIL_STATS" => File.join(dir, "wrapper-#{mode}") })
          skip "install activerecord 8.1.4 and sqlite3 to run preload integration tests" if err.include?("Could not find 'activerecord'")
          assert status.success?, "#{err}\n#{out}"
          JSON.parse(out.lines.last).tap { assert_empty _1.delete("hits") }
        end
        assert_equal runs.first, runs.last
        assert_equal [7], runs.last["unit_ids"] if patch == "batch"
        assert_operator runs.last["build_wrapper_calls"], :>, 10
      end
    end
  end

  def test_inherited_singleton_getter_fact_names_its_real_owner
    skip "Rails is not installed" unless LowrailTest.rails_installed?
    fact = ruby_json(<<~'RUBY')
      gem "activerecord", "~> 8.1.4"
      require "active_record"
      require "lowrail/preload_facts"
      ActiveRecord::Base.class_attribute :lowrail_owner_probe, default: 17
      class Post < ActiveRecord::Base; end
      puts JSON.generate(Lowrail::PreloadFacts.method_fact(Post, :lowrail_owner_probe, singleton: true))
    RUBY
    assert_equal "Post", fact.fetch("receiver")
    assert_equal "#<Class:ActiveRecord::Base>", fact.fetch("owner")
  end
end
