# frozen_string_literal: true

# Unit test for the boot fact dumper on plain Ruby (no Rails needed):
#   ruby -Igem/lib gem/test/facts_test.rb

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "digest"
require "lowrail/facts"

module FactsFixture
  class Plain
    attr_reader :r
    attr_writer :w
    def m(a, b = 1, *rest, k:, **opts, &blk); end
    define_method(:dm) { |x| x }
    class_eval "def ev; end"
    alias al m
    def self.sing; end

    protected def prot; end

    private

    def priv; end
  end

  class Basic < BasicObject
    def hello; end
  end

  # Overrides every reflective method a naive dumper would call.
  class Hostile
    def self.name = raise("no name for you")
    def self.inspect = raise("no inspect")
    def self.to_s = raise("no to_s")
    def self.respond_to?(*) = raise("no respond_to?")
    def self.method(*) = raise("no method")
    def self.instance_methods(*) = raise("no instance_methods")
    def self.ancestors = raise("no ancestors")
    def self.singleton_class = raise("no singleton_class")
    def ok; end
  end

  ANON = [Module.new { def anon_m; end }, Class.new]
end

class FactsTest < Minitest::Test
  def facts
    @facts ||= Lowrail::Facts.collect(app_root: __dir__)
  end

  def mod(name)
    facts["modules"].find { |m| m["name"] == name } or flunk "module #{name} not dumped"
  end

  def meth(mod_name, name, singleton: false)
    mod(mod_name)["methods"].find { |m| m["name"] == name && m["singleton"] == singleton } or
      flunk "#{mod_name} #{name} not dumped"
  end

  def test_top_level_shape
    assert_equal 1, facts["format"]
    assert_equal RUBY_DESCRIPTION, facts["ruby_description"]
    assert_nil facts["rails_version"]
    assert_equal [], facts["models"]
    assert_equal [], facts["controllers"]
    assert_equal [], facts["routes"]
    assert_includes facts["load_path_features"], File.expand_path("../lib/lowrail/facts.rb", __dir__)
    assert(facts["gems"].any? { |g| g["name"] == "minitest" })
    assert_equal facts["modules"].map { |m| m["name"] }.sort, facts["modules"].map { |m| m["name"] }
  end

  def test_iseq_kinds
    c = "FactsFixture::Plain"
    assert_equal "method", meth(c, "m")["iseq_kind"]
    assert_equal "block", meth(c, "dm")["iseq_kind"]
    assert_equal "eval", meth(c, "ev")["iseq_kind"]
    assert_match(/\A\(eval at #{Regexp.escape(__FILE__)}:\d+\):1\z/, meth(c, "ev")["source_location"])
    assert_equal "attr_reader", meth(c, "r")["iseq_kind"]
    assert_equal "attr_writer", meth(c, "w=")["iseq_kind"]
    assert_equal "cfunc", meth("String", "upcase")["iseq_kind"]
    assert_equal "method", meth(c, "sing", singleton: true)["iseq_kind"]
  end

  def test_method_details
    c = "FactsFixture::Plain"
    m = meth(c, "m")
    assert_equal "#{__FILE__}:#{FactsFixture::Plain.instance_method(:m).source_location[1]}", m["source_location"]
    assert_equal [%w[req a], %w[opt b], %w[rest rest], %w[keyreq k], %w[keyrest opts], %w[block blk]], m["parameters"]
    assert_equal c, m["owner"]
    assert_equal "public", m["visibility"]
    refute m.key?("original_name")
    assert_equal "m", meth(c, "al")["original_name"]
    assert_equal "private", meth(c, "priv")["visibility"]
    assert_equal "protected", meth(c, "prot")["visibility"]
    assert_equal "class", mod(c)["kind"]
    assert_equal "Object", mod(c)["superclass"]
    assert_equal "#<Class:FactsFixture::Plain>", mod(c)["singleton_ancestors"].first
    assert_match(/facts_test\.rb:\d+\z/, mod(c)["const_source_location"])
    assert_equal "module", mod("FactsFixture")["kind"]
  end

  def test_basic_object_and_hostile_modules
    assert_equal "BasicObject", mod("FactsFixture::Basic")["superclass"]
    assert_equal "method", meth("FactsFixture::Basic", "hello")["iseq_kind"]
    # Overridden `name` is bypassed: the module is listed under its real name.
    h = mod("FactsFixture::Hostile")
    assert_equal "FactsFixture::Hostile", h["ancestors"].first
    assert_equal "method", meth("FactsFixture::Hostile", "ok")["iseq_kind"]
    assert_equal "method", meth("FactsFixture::Hostile", "name", singleton: true)["iseq_kind"]
    assert_equal [], facts["errors"]
  end

  def test_anonymous_modules_are_counted_not_listed
    assert_operator facts["module_stats"]["anonymous"], :>=, 2
    refute(facts["modules"].any? { |m| m["name"].include?("#<") })
    assert_equal facts["modules"].size, facts["module_stats"]["named"]
    assert_equal facts["modules"].sum { |m| m["methods"].size }, facts["module_stats"]["methods"]
  end

  def test_errors_are_recorded_not_raised
    Lowrail::Facts.record("before collect", RuntimeError.new("boom\nsecond line"))
    f = Lowrail::Facts.collect
    assert_equal [{"where" => "before collect", "kind" => "error", "error" => "RuntimeError: boom"}], f["errors"]
    assert_nil Lowrail::Facts.guard("x") { raise ArgumentError, "bad" }
    assert_equal "ArgumentError: bad", Lowrail::Facts.collect["errors"].first["error"]
  end

  def test_dump_to_io_and_path_is_deterministic
    io = StringIO.new
    Lowrail::Facts.dump(io, timings: {boot_seconds: 1.5})
    parsed = JSON.parse(io.string)
    assert_equal 1.5, parsed["timings"]["boot_seconds"]
    assert_kind_of Float, parsed["timings"]["dump_seconds"]
    Dir.mktmpdir do |dir|
      path = File.join(dir, "facts.json")
      Lowrail::Facts.dump(path)
      again = JSON.parse(File.read(path))
      [parsed, again].each { |f| f.delete("timings") }
      assert_equal parsed["modules"].find { |m| m["name"] == "FactsFixture::Plain" },
        again["modules"].find { |m| m["name"] == "FactsFixture::Plain" }
      assert_equal [File.basename(path)], Dir.children(dir)
    end
  end
end

# Integration: boot the real-blog corpus app (skipped when it is absent).
class FactsRealBlogTest < Minitest::Test
  APP = File.expand_path("../../.corpus/real-blog", __dir__)
  EXE = File.expand_path("../exe/lowrail-facts", __dir__)

  def self.facts
    @facts ||= Dir.mktmpdir do |dir|
      out = File.join(dir, "facts.json")
      run = -> { system("bundle", "exec", "ruby", EXE, out, chdir: APP, err: File::NULL) }
      ok = defined?(Bundler) ? Bundler.with_unbundled_env(&run) : run.call
      ok ? JSON.parse(File.read(out)) : {}
    end
  end

  def setup
    skip "no #{APP} (see script/corpus)" unless File.exist?(File.join(APP, "Gemfile.lock"))
    @f = self.class.facts
    refute_empty @f, "lowrail-facts failed in #{APP}"
  end

  def test_rails_sections
    assert_equal APP, @f["app_root"]
    assert_match(/\A8\./, @f["rails_version"])
    assert_equal %w[Article Comment], @f["models"].map { |m| m["name"] }
    article = @f["models"].first
    assert_equal %w[id title body created_at updated_at], article["columns"].map { |c| c["name"] }
    assert_equal [["has_many", "comments", "Comment"]], article["associations"].map { |a| a.values_at("macro", "name", "class_name") }
    articles = @f["controllers"].find { |c| c["name"] == "ArticlesController" }
    assert_equal %w[create destroy edit index new show update], articles["actions"]
    assert(articles["callbacks"].any? { |c| c["filter"] == "set_article" && c["conditions"] })
    assert(@f["routes"].any? { |r| r.values_at("verb", "path", "name") == ["GET", "/articles(.:format)", "articles"] })
    assert(@f["routes"].any? { |r| r["app"] == "ActionCable::Server::Base" })
    assert_empty @f["errors"].reject { |e| e["kind"] == "skipped" }
    assert_equal %w[boot_seconds dump_seconds eager_load_seconds], @f["timings"].keys
  end

  def test_templates
    index = @f["templates"].find { |t| t["virtual_path"] == "articles/index" && t["format"] == "html" }
    assert_equal "ActionView::Template::Handlers::ERB", index["handler"]
    assert_includes index["code"], "@output_buffer"
    assert_equal Digest::SHA256.file(index["identifier"]).hexdigest, index["source_sha256"]
    assert_equal({"frozen_string_literal" => false, "annotate_rendered_view_with_filenames" => false}, @f["template_config"])
  end

  def test_app_methods
    articles = @f["modules"].find { |m| m["name"] == "ArticlesController" }
    show = articles["methods"].find { |m| m["name"] == "show" }
    assert_equal "#{APP}/app/controllers/articles_controller.rb:10", show["source_location"]
    attrs = @f["modules"].find { |m| m["name"] == "Article::GeneratedAttributeMethods" }
    assert(attrs["methods"].any? { |m| m["name"] == "title" }, "attribute methods are defined before the dump")
  end
end
