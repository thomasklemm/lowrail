# frozen_string_literal: true

require_relative "test_helper"

class ARInstantiateTest < Minitest::Test
  include LowrailTest

  SCENARIO = <<~'RUBY'
    gem "activerecord", "8.1.4"
    require "active_record"
    require "lowrail"
    require "lowrail/manifest"
    require "lowrail/ar_instantiate_build"
    module Rails
      def self.version = ActiveRecord::VERSION::STRING
    end
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table(:writers) { |t| t.string :name }
      create_table(:posts) { |t| t.integer :writer_id; t.string :title; t.integer :score }
      create_table(:vehicles) { |t| t.string :type; t.string :name }
    end
    class CountedType < ActiveRecord::Type::Integer
      def deserialize(value)
        $casts = ($casts || 0) + 1
        super
      end
    end
    class Writer < ActiveRecord::Base
      has_many :posts, inverse_of: :writer
    end
    class Post < ActiveRecord::Base
      belongs_to :writer, inverse_of: :posts
      attribute :score, CountedType.new
    end
    class CustomPost < Post
      attr_reader :custom, :internal
      def init_with_attributes(attributes, new_record = false)
        super
        @custom = title.reverse
        self
      end
      private
      def init_internals
        super
        @internal = title + "-internal"
      end
    end
    class CustomBuilderPost < Post
      def self.attributes_builder
        $builder_calls = ($builder_calls || 0) + 1
        super
      end
    end
    class CustomMetadataPost < Post
      def self.column_names
        $metadata_calls = ($metadata_calls || 0) + 1
        super
      end
    end
    class Vehicle < ActiveRecord::Base; end
    class Bicycle < Vehicle; end
    class LatePost < Post; end
    class BlockPost < Post; end
    class SchemaPost < Post; end
    class DispatchPost < Post; end
    a = Writer.create!(name: "Ada")
    x = a.posts.create!(title: "left", score: 17)
    y = a.posts.create!(title: "right", score: 29)
    Bicycle.create!(name: "two wheels")
    Vehicle.create!(name: "plain")
    File.write("manifest.json", JSON.generate({format: 1, ruby_description: RUBY_DESCRIPTION,
      compile_option: Lowrail::Manifest.compile_option_fingerprint, files: {}, units: [{id: 4, facts: []}]}))
    File.write("ledger.json", "[]")
    built = Lowrail::ARInstantiateBuild.build
    built[:units].each_with_index { |unit, i| unit["id"] = 5 + i }
    data = JSON.parse(File.read("manifest.json"))
    data["units"].concat(built[:units])
    File.write("manifest.json", JSON.generate(data))
    File.write("ledger.json", JSON.generate(built[:ledger]))
    manifest = JSON.parse(File.read("manifest.json"))
    raise "unit collision" unless manifest["units"].map { _1["id"] }.uniq.size == manifest["units"].size
    if defined?(ActiveRecord::ModelSchema::SchemaContext)
      raise "custom alpha metadata lowered" if manifest["units"].any? { _1.dig("ar_instantiate", "model") == "CustomMetadataPost" }
    end
    if ENV["STALE_AR"]
      manifest["units"].each { |u| u["ar_instantiate"]&.fetch("sources")&.transform_values! { "stale" } }
      File.write("manifest.json", JSON.generate(manifest))
    end
    # Late setup must activate immediately through the shared hook. Empty
    # selections still skip installation and therefore have no fast paths.
    ActiveSupport.run_load_hooks(:after_initialize)
    Lowrail.setup(root: Dir.pwd, dir: Dir.pwd)
    events = []
    subscription = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |*args|
      payload = args.last
      events << [payload[:class_name], payload[:record_count], args.first.frozen?]
    end
    $casts = 0
    records = Post.order(:id).readonly.strict_loading.to_a
    lazy = $casts
    snapshot = records.map { [_1.title, _1.score, _1.new_record?, _1.previously_new_record?, _1.readonly?, _1.strict_loading?] }
    raise "not lazy" unless lazy == 0 && $casts == 2
    frozen = Post.all.load.records.frozen?
    inverse = Writer.includes(:posts).find(a.id).then { |w| w.posts.all? { _1.writer.equal?(w) } }
    custom = CustomPost.order(:id).map { [_1.custom, _1.internal] }
    projected = Post._load_from_sql(ActiveRecord::Result.new(["score", "extra_number"], [["31", "47"]],
      [ActiveRecord::Type::String.new, ActiveRecord::Type::Integer.new])).first
    projection = [projected.score, projected["extra_number"]]
    builder_before = ($builder_calls || 0)
    CustomBuilderPost.order(:id).to_a
    builder_calls = $builder_calls - builder_before
    metadata_before = ($metadata_calls || 0)
    metadata_rows = CustomMetadataPost.order(:id).map(&:title)
    metadata_calls = $metadata_calls - metadata_before
    sti = Vehicle.order(:id).map { [_1.class.name, _1.name] }
    # Warm before adding callbacks: a boot-time "empty" assumption must expire.
    LatePost.first
    LatePost.after_initialize { @late = title.upcase }
    late = LatePost.order(:id).map { _1.instance_variable_get(:@late) }
    # Mutation inside a yield affects the very first row's callbacks, then
    # the second row's builder. Never replay the first row or cast eagerly.
    yielded = []
    block_rows = BlockPost.find_by_sql("SELECT * FROM posts ORDER BY id") do |r|
      yielded << r.title
      if yielded.size == 1
        BlockPost.attribute :marker, :string, default: "late-default"
        BlockPost.after_initialize { @from_callback = title.upcase }
      end
      r.strict_loading!
    end
    block_result = block_rows.map { [_1.title, _1.has_attribute?(:marker), _1.instance_variable_get(:@from_callback), _1.strict_loading?] }
    SchemaPost.first
    ActiveRecord::Base.connection.add_column(:posts, :extra, :integer, default: 43)
    SchemaPost.reset_column_information
    schema = SchemaPost.first.extra
    # Singleton override between rows must take effect on the next row.
    dispatched = []
    DispatchPost.find_by_sql("SELECT * FROM posts ORDER BY id") do |r|
      dispatched << r.title
      if dispatched.size == 1
        def DispatchPost.instantiate_instance_of(klass, attributes, column_types = {}, &block)
          super.tap { _1.instance_variable_set(:@dispatch, true) }
        end
      end
    end.then { |rs| dispatched << rs.map { !!_1.instance_variable_get(:@dispatch) } }
    # A subclass introduced after installation must not inherit the parent's
    # cached builder or elide its customized initializer.
    class NewPost < Post
      def init_with_attributes(attributes, new_record = false)
        super.tap { @new_subclass = title + "!" }
      end
    end
    new_subclass = NewPost.first.instance_variable_get(:@new_subclass)
    empty_events = events.size
    empty = Post.find_by_sql("SELECT * FROM posts WHERE 1=0")
    raise "empty instrumentation" unless empty.empty? && events.size == empty_events
    ActiveSupport::Notifications.unsubscribe(subscription)
    hits = defined?(Lowrail::Stats) ? Lowrail::Stats.unit_hits.values.sum : 0
    puts JSON.generate(snapshot: snapshot, frozen: frozen, inverse: inverse, custom: custom,
      projection: projection, builder_calls: builder_calls, metadata: [metadata_rows, metadata_calls],
      sti: sti, late: late, yielded: yielded, block: block_result,
      schema: schema, dispatch: dispatched, new_subclass: new_subclass, events: events, hits: hits)
  RUBY

  def test_real_loading_matches_rails_across_mutation_and_overrides
    skip "Rails is not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      off = ruby_json(SCENARIO, chdir: dir, env: { "LOWRAIL" => "0", "LOWRAIL_STATS" => "" })
      assert_equal [["left", 17, false, false, true, true], ["right", 29, false, false, true, true]], off["snapshot"]
      assert_equal true, off["frozen"]
      assert_equal true, off["inverse"]
      assert_equal [["tfel", "left-internal"], ["thgir", "right-internal"]], off["custom"]
      assert_equal [31, 47], off["projection"]
      assert_equal 2, off["builder_calls"]
      assert_equal ["left", "right"], off["metadata"].first
      assert_equal [["Bicycle", "two wheels"], ["Vehicle", "plain"]], off["sti"]
      assert_equal ["LEFT", "RIGHT"], off["late"]
      assert_equal ["left", "right"], off["yielded"]
      assert_equal [["left", false, "LEFT", true], ["right", true, "RIGHT", true]], off["block"]
      assert_equal 43, off["schema"]
      assert_equal ["left", "right", [false, true]], off["dispatch"]
      assert_equal "left!", off["new_subclass"]
      assert_includes off["events"], ["Post", 2, true]
      assert_includes off["events"], ["Vehicle", 2, true]
      on = ruby_json(SCENARIO, chdir: dir, env: { "LOWRAIL" => "1", "LOWRAIL_STATS" => "" })
      assert_operator on.delete("hits"), :>, 0
      off.delete("hits")
      assert_equal off, on
      [{ "LOWRAIL_UNITS" => "" }, { "STALE_AR" => "1" }].each do |control|
        result = ruby_json(SCENARIO, chdir: dir, env: { "LOWRAIL" => "1", "LOWRAIL_STATS" => "" }.merge(control))
        assert_equal 0, result.delete("hits")
        assert_equal off, result
      end
    end
  end

  def test_early_setup_preserves_locale_and_lazy_model_loading
    skip "Rails is not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      model = LowrailTest::RAILS_APP.fetch("app/models/widget.rb").sub(
        "enum :status", "BOOT_DATE = I18n.l(Date.new(1997, 2, 13))\n  enum :status")
      LowrailTest.write_rails_app(dir, "app/models/widget.rb" => model,
        "app/models/deferred_widget.rb" => <<~'RUBY',
          $deferred_widget_loaded = true
          class DeferredWidget < ApplicationRecord
            self.table_name = "widgets"
          end
        RUBY
        "config/locales/en.yml" => "en:\n  date:\n    formats:\n      default: '%d.%m.%Y'\n")
      FileUtils.mkdir_p(File.join(dir, ".lowrail"))
      build = ruby_json(<<~'RUBY', chdir: dir, setup: false, env: { "RAILS_ENV" => "test", "RUBYLIB" => GEM_LIB })
        require_relative "config/environment"
        require "lowrail/ar_instantiate_build"
        Widget
        DeferredWidget
        built = Lowrail::ARInstantiateBuild.build
        built[:units].each_with_index { |unit, id| unit["id"] = id }
        File.write(".lowrail/manifest.json", JSON.generate(format: 1,
          ruby_description: RUBY_DESCRIPTION, compile_option: "", files: {}, units: built[:units]))
        puts JSON.generate(built[:units].map { _1.fetch("ar_instantiate").fetch("model") })
      RUBY
      assert_includes build, "Widget"
      assert_includes build, "DeferredWidget"
      code = <<~'RUBY'
        require_relative "config/environment"
        loaded_at_boot = !!$deferred_widget_loaded
        Widget.create!(name: "localized", password: "password")
        puts JSON.generate(date: Widget::BOOT_DATE, name: Widget.first.name, loaded_at_boot: loaded_at_boot,
          deferred: DeferredWidget.first.name,
          hits: defined?(Lowrail::Stats) ? Lowrail::Stats.unit_hits.values.sum : 0)
      RUBY
      off, on = %w[0 1].map do |mode|
        ruby_json(code, chdir: dir, env: { "RAILS_ENV" => "test", "LOWRAIL" => mode, "LOWRAIL_STATS" => "" })
      end
      assert_equal "13.02.1997", off.fetch("date")
      assert_equal false, off.fetch("loaded_at_boot")
      assert_operator on.delete("hits"), :>, 0
      off.delete("hits")
      assert_equal off, on
    end
  end
end
