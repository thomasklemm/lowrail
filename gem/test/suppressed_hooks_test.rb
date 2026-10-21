# frozen_string_literal: true

require_relative "test_helper"

class SuppressedHooksTest < Minitest::Test
  include LowrailTest

  PASSES = %w[inertia/config_bind memo/sha256 memo/uri_join digest/file_memo
    active_record/preload_plans active_record/instantiate active_record/ar_plans].freeze

  # Physical source is important: AR's scoped-reader builder certifies the
  # lambda's real file, not an eval fixture. Every scenario boots real Rails.
  MODELS = <<~'RUBY'
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table(:writers) { |t| t.string :name }
      create_table(:posts) { |t| t.integer :writer_id; t.string :title }
    end
    class Writer < ActiveRecord::Base
      has_many :posts
      has_many :preferred_posts, -> { order(:title).limit(2) }, class_name: "Post"
    end
    class Post < ActiveRecord::Base
      belongs_to :writer
    end
    a = Writer.create!(name: "left")
    b = Writer.create!(name: "right")
    a.posts.create!(title: "z"); a.posts.create!(title: "a")
    b.posts.create!(title: "foreign")
  RUBY

  SCENARIO = <<~'RUBY'
    # file_memo deliberately certifies 3.2.1, not Ruby 4.1's default 3.3.0.
    gem "digest", "3.2.1"
    require "./config/environment"
    require "./models"
    require "lowrail/compiler"
    require "lowrail/stats"
    Lowrail::Stats.enable!
    pass = ENV.fetch("AUDIT_PASS")
    case pass
    when "inertia/config_bind"
      gem "inertia_rails", "3.23.0"
      require "inertia_rails"
      require "lowrail/inertia_config_build"
      units = Lowrail::InertiaConfigBuild.build.fetch(:units)
      config = InertiaRails::Configuration.default
      config.version = "before-warmup"
      operation = -> { config.bind_controller(Object.new).version }
      mutation = -> {
        extract = Hash.instance_method(:extract!)
        Hash.define_singleton_method(:method_added) { |_| }
        Hash.define_method(:extract!) do |*keys|
          extract.bind_call(self, *keys).tap { _1[:version] = "changed-after-warmup" }
        end
      }
    when "memo/sha256", "memo/uri_join", "digest/file_memo"
      require "lowrail/memo_facts"
      if pass == "digest/file_memo"
        require "digest/md5"
        require "lowrail/digest_memo_build"
        facts, sources = Lowrail::DigestMemoBuild.certify(["Digest::MD5"])
        unit = {"facts" => facts, "digest_memo" => {"sources" => sources, "algorithms" => ["Digest::MD5"]}}
        File.write("bytes", "asymmetric file bytes")
        old = 'Digest::MD5.file("bytes").hexdigest'
        fast = 'Lowrail::DigestMemo.hexdigest(0, Digest::MD5, "bytes")'
        mutation = -> {
          Digest::MD5.define_singleton_method(:singleton_method_added) { |_| }
          Digest::MD5.define_singleton_method(:file) { |_| Struct.new(:hexdigest).new("changed-after-warmup") }
        }
      elsif pass == "memo/sha256"
        cert = Lowrail::MemoFacts.digest
        unit = {"facts" => cert.fetch("facts"), "memo" => cert}
        old = 'Digest::SHA256.base64digest("left")'
        fast = 'Lowrail::Memo.digest(0, Digest::SHA256, "left") { |r,s| r.base64digest(s) }'
        mutation = -> {
          Digest::SHA256.define_singleton_method(:singleton_method_added) { |_| }
          Digest::SHA256.define_singleton_method(:base64digest) { |_| "changed-after-warmup" }
        }
      else
        cert = Lowrail::MemoFacts.build
        raise cert.inspect if cert["decline"]
        unit = {"facts" => cert.fetch("facts"), "memo" => cert}
        old = 'URI.join("https://one.test/root/", "child").to_s'
        fast = 'Lowrail::Memo.join(0, URI, "https://one.test/root/", "child") { |r,b,u| r.join(b,u) }.to_s'
        mutation = -> {
          URI.define_singleton_method(:singleton_method_added) { |_| }
          URI.define_singleton_method(:join) { |*| URI::HTTPS.build(host: "changed.test", path: "/after-warmup") }
        }
      end
      path = File.expand_path("operation.rb")
      File.write(path, "class AuditOperation; def self.call; #{old}; end; end\n")
      File.write("lowered.rb", "class AuditOperation; def self.call; #{fast}; end; end\n")
      units = [unit.merge("kind" => "file", "file" => path, "pass" => pass)]
      files = [{"path" => path, "lowered" => File.expand_path("lowered.rb")}]
      operation = -> { AuditOperation.call }
    else
      require "lowrail/ar_guard"
      Lowrail::AR.install
      case pass
      when "active_record/instantiate"
        require "lowrail/ar_instantiate_build"
        units = Lowrail::ARInstantiateBuild.build.fetch(:units)
        operation = -> { Post.order(:id).map(&:title) }
        mutation = -> {
          original = Post.method(:instantiate_instance_of)
          Post.define_singleton_method(:singleton_method_added) { |_| }
          Post.define_singleton_method(:instantiate_instance_of) do |*args, &block|
            original.call(*args, &block).tap { _1.title = "changed-after-warmup" }
          end
        }
      when "active_record/preload_plans"
        require "lowrail/preload_build"
        units = Lowrail::PreloadBuild.build.fetch(:units)
        operation = -> {
          owners = Writer.order(:id).to_a
          ActiveRecord::Associations::Preloader.new(records: owners, associations: :posts).call
          owners.map { _1.posts.map(&:title) }
        }
        mutation = -> {
          original = Post.method(:scope_for_association)
          Post.define_singleton_method(:singleton_method_added) { |_| }
          Post.define_singleton_method(:scope_for_association) { |*args| original.call(*args).where(title: "a") }
        }
      when "active_record/ar_plans"
        require "lowrail/ar_plan_build"
        units = Lowrail::ARPlanBuild.build.fetch(:units)
        events = []
        ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| events << p[:sql] if p[:sql].include?('FROM "posts"') }
        operation = -> {
          events.clear
          rows = Writer.order(:id).map { _1.preferred_posts.map(&:title) }
          [rows, events.dup]
        }
        mutation = -> {
          owner = Arel::Visitors::SQLite.instance_method(:visit_Arel_Nodes_SelectStatement).owner
          original = owner.instance_method(:visit_Arel_Nodes_SelectStatement)
          owner.define_singleton_method(:method_added) { |_| }
          owner.define_method(:visit_Arel_Nodes_SelectStatement) { |node, collector| original.bind_call(self, node, collector) << " /* changed-after-warmup */" }
          owner.send(:private, :visit_Arel_Nodes_SelectStatement)
        }
      end
    end
    raise "no units: #{pass}" if units.empty?
    units.each_with_index { _1["id"] = _2 }
    input = {"out" => File.expand_path(".lowrail"), "units" => units, "files" => files || []}
    input.merge!("tier" => "sealed-v1", "rails_env" => "production") if ENV["ARTIFACT"] == "sealed"
    Lowrail::Compiler.compile(input)
    Lowrail.setup(root: Dir.pwd)
    require "./operation" if files
    before = Array.new(3) { operation.call }.last
    hits = Lowrail::Stats.unit_hits.values.sum
    epochs = [Lowrail::AR.epoch(Writer), Lowrail::AR.epoch(Post)] if defined?(Lowrail::AR)
    mutation.call unless ENV["ARTIFACT"] == "sealed"
    after = operation.call
    raise "AR epoch changed" if epochs && epochs != [Lowrail::AR.epoch(Writer), Lowrail::AR.epoch(Post)]
    puts JSON.generate(before: before, after: after, hits: hits, refusal: Lowrail.refusal_reason)
  RUBY

  def test_old_guarded_artifacts_follow_suppressed_mutations_and_production_sealed_units_hit
    missing_prerequisite "Rails/sqlite3/bcrypt and inertia_rails 3.23.0 required" unless LowrailTest.rails_installed? &&
      Gem::Specification.find_all_by_name("inertia_rails", "3.23.0").any?
    PASSES.each do |pass|
      realpath_tmpdir do |dir|
        LowrailTest.write_rails_app(dir, "config/database.yml" => "production:\n  adapter: sqlite3\n  database: ':memory:'\n")
        File.write(File.join(dir, "models.rb"), MODELS)
        File.write(File.join(dir, "scenario.rb"), SCENARIO)
        outputs = [["0", nil], ["1", nil], ["1", "sealed"]].map do |mode, artifact|
          ruby_json('load "./scenario.rb"', chdir: dir, env: {"LOWRAIL" => mode, "RAILS_ENV" => "production",
            "LOWRAIL_SEALED" => "1", "AUDIT_PASS" => pass, "ARTIFACT" => artifact})
        end
        off, refused, sealed = outputs
        assert_equal off.fetch("before"), refused.fetch("before"), pass
        refute_equal off.fetch("before"), off.fetch("after"), "mutation control: #{pass}"
        assert_equal off.fetch("after"), refused.fetch("after"), pass
        assert_equal 0, refused.fetch("hits"), pass
        assert_match(/sealed-only.*SEAL001/, refused.fetch("refusal"), pass)
        assert_operator sealed.fetch("hits"), :>, 0, "public production activation: #{pass}"
        assert_equal off.fetch("before"), sealed.fetch("before"), pass
        assert_equal sealed.fetch("before"), sealed.fetch("after"), pass
      end
    end
  end
end
