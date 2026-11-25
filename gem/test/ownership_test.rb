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
