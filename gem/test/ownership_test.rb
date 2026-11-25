# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
load File.expand_path("../../script/ownership", __dir__)

class OwnershipTest < Minitest::Test
  def test_method_names_come_from_changed_lines_outside_tests
    files = [
      { "filename" => "actionpack/lib/http_authentication.rb",
        "patch" => "@@ -1,3 +1,3 @@ def opaque(key)\n   def untouched\n-  def authenticate(controller)\n+  def authenticate(controller, scheme: nil)\n+  def self.normalize_scheme(s)\n+  def valid?\n" },
      { "filename" => "zjit/src/codegen.rs", "patch" => "+fn gen_send_block_arg(jit: &mut JITState) {\n" },
      { "filename" => "actionpack/test/controller/http_token_authentication_test.rb", "patch" => "+  def dpop\n" }
    ]
    assert_equal %w[authenticate normalize_scheme valid? gen_send_block_arg], Ownership.method_names(files)
  end

  LR1_PATCH = <<~DIFF
    @@ -212,7 +212,7 @@ def initialize
             end
     
             def lease(context)
    -          @lease_mutex.synchronize do
    +          self[context] || @lease_mutex.synchronize do
                 fetch_or_store(context) do
                   Lease.new(@terminated_flag)
                 end
    @@ -300,6 +300,7 @@ def checkout(timeout = nil)
               conn = acquire
    +          conn.lease
             end
     
             def release(conn)
  DIFF

  def test_a_change_inside_a_method_body_names_that_method
    files = [{ "filename" => "activerecord/lib/connection_pool.rb", "patch" => LR1_PATCH }]
    assert_equal %w[lease checkout], Ownership.method_names(files)

    added_after_the_header_method = <<~DIFF
      @@ -370,6 +370,9 @@ def to_hash
             end
           end
       
      +    #: () -> Hash[String, untyped]
      +    def values_for_database
      +    end
       
           def fetch_value(name, &block)
    DIFF
    assert_equal %w[values_for_database], Ownership.method_names([{ "filename" => "attribute_set.rb", "patch" => added_after_the_header_method }])
  end

  POOL = "activerecord/lib/connection_pool.rb"

  def fake_gh(*args)
    query = args.find { _1.start_with?("query=") }.to_s
    if query.include?("timelineItems")
      { "data" => { "repository" => { "issueOrPullRequest" => { "title" => "t", "state" => "MERGED", "timelineItems" => { "nodes" => [] } } } } }
    elsif args.first == "graphql"
      pr = ->(number, path) { { "number" => number, "title" => "PR #{number}", "state" => "OPEN", "author" => { "login" => "a" },
                                "repository" => { "nameWithOwner" => "rails/rails" }, "files" => { "nodes" => [{ "path" => path }] } } }
      { "data" => { "search" => { "issueCount" => 96, "nodes" => [pr.(10, POOL), pr.(11, "activemodel/lib/dirty.rb")] } } }
    elsif args.first.include?("/pulls/1/files")
      [{ "filename" => "activerecord/lib/other.rb", "patch" => "@@ -1 +1 @@\n+  def checkout_lease\n" }]
    elsif args.first.include?("/compare/")
      { "files" => [{ "filename" => POOL, "patch" => LR1_PATCH }] }
    end
  end

  def check_lr1
    original = PrQueue.method(:gh)
    fake = method(:fake_gh)
    PrQueue.define_singleton_method(:gh) { |*args| fake.(*args) }
    meta = { "id" => "LR1", "repo" => "rails/rails", "base" => "main", "branch" => "lease", "introduced_by" => 1 }
    Ownership.check(PrQueue::Item.new("LR1.md", meta, "t", ""))
  ensure
    PrQueue.define_singleton_method(:gh, original)
  end

  def test_names_come_from_the_branch_not_the_introducing_pr
    checked, = check_lr1
    assert_includes checked, "open PRs naming lease, checkout that change #{POOL}"
  end

  def test_a_name_hit_must_change_one_of_the_items_files
    _, hits = check_lr1
    assert_equal ["rails/rails#10"], hits.map { _1[%r{rails/rails#\d+}] }
  end

  def test_open_refuses_without_a_check_from_the_last_three_days
    Dir.mktmpdir do |dir|
      path = File.join(dir, "X1.md")
      File.write(path, "---\nid: X1\nstate: reviewed\npasses: []\n---\n\n# Title\n\nBody.\n")
      item = PrQueue.parse(path)
      assert_equal "no ownership check; run script/ownership X1", PrQueue.ownership_blocker(item.meta)

      Ownership.record(item, Ownership.line(Date.new(2026, 11, 22), ["open PRs cross-referencing #58211"], ['references #58211: a "PR": x']))
      item = PrQueue.parse(path)
      assert_equal ['references #58211: a "PR": x'], item["ownership"]["hits"]
      assert_nil PrQueue.ownership_blocker(item.meta, Date.new(2026, 11, 25))
      assert_match(/older than 3 days/, PrQueue.ownership_blocker(item.meta, Date.new(2026, 11, 26)))

      Ownership.record(item, Ownership.line(Date.new(2026, 11, 26), [], []))
      assert_equal 1, File.read(path).scan(/^ownership:/).size
      assert_nil PrQueue.ownership_blocker(PrQueue.parse(path).meta, Date.new(2026, 11, 26))
    end
  end
end
