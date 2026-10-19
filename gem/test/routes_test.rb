# frozen_string_literal: true

require_relative "test_helper"

# Runtime pieces of the route-helper pass: Lowrail::Routes (prefix, seg) and
# per-class "@self" facts, including route facts against a stand-in route
# set. Real Rails behavior is checked at build time by the oracle probes and
# end to end by `lowrail verify` on the corpus apps.
class RoutesTest < Minitest::Test
  include LowrailTest

  def test_prefix_mirrors_find_script_name_and_path_for
    out = ruby_json(<<~'RUBY')
      require "json"
      require "lowrail"
      require "lowrail/routes"
      Routes = Struct.new(:relative_url_root)
      T = Struct.new(:_routes)
      t = T.new(Routes.new(nil))
      r = Lowrail::Routes
      dflt = Hash.new(1)
      res = {
        empty: r.prefix({}, t),
        blank: r.prefix({ script_name: "" }, t),
        sub: r.prefix({ script_name: "/sub/" }, t),
        nil_script: r.prefix({ script_name: nil }, T.new(Routes.new("/root/"))),
        root: r.prefix({ host: "x" }, T.new(Routes.new("/root"))),
        slash: r.prefix({ trailing_slash: true }, t),
        original: r.prefix({ original_script_name: "/a" }, t),
        params: r.prefix({ params: {} }, t),
        anchor: r.prefix({ anchor: "x" }, t),
        default: r.prefix(dflt, t),
        subclass: r.prefix(Class.new(Hash).new, t),
        new_string: (s = +"/s"; !r.prefix({ script_name: s }, t).equal?(s))
      }
      puts JSON.generate(res)
    RUBY
    assert_equal({ "empty" => "", "blank" => "", "sub" => "/sub", "nil_script" => "/root", "root" => "/root",
                   "slash" => nil, "original" => nil, "params" => nil, "anchor" => nil, "default" => nil,
                   "subclass" => nil, "new_string" => true }, out)
  end

  def test_seg_skips_gsub_only_for_safe_ascii
    out = ruby_json(<<~'RUBY')
      require "json"
      require "lowrail"
      require "lowrail/routes"
      module ActionDispatch; module Journey; module Router; module Utils
        class UriEncoder; SEGMENT = /[^a-z0-9]/; end
        def self.escape_segment(s) = "esc(#{s})"
      end; end; end; end
      safe = "abc123"
      broken = (+"\xFF").force_encoding("UTF-8")
      puts JSON.generate([Lowrail::Routes.seg(safe).equal?(safe), Lowrail::Routes.seg("a b"),
                          Lowrail::Routes.seg("café"), Lowrail::Routes.seg(broken).b == "esc(\xFF)".b])
    RUBY
    assert_equal [true, "esc(a b)", "esc(café)", true], out
  end

  # "@self" facts are checked against the class passed to Lowrail.ok? and
  # cached per class; route facts also require the helper to be the route
  # set's method for an unchanged route.
  def test_ok_checks_self_facts_per_class_and_route_facts
    out = ruby_json(<<~'RUBY')
      require "json"
      require "lowrail"
      require "lowrail/manifest"
      require "lowrail/guard"
      require "lowrail/loader"
      Route = Struct.new(:spec_s, :required_parts, :defaults, :requirements) do
        def path = Struct.new(:spec, :requirements).new(spec_s, requirements)
      end
      Named = Struct.new(:path_helpers_module, :routes) do
        def get(name) = routes[name.to_sym]
      end
      $helpers = Module.new { def article_path(a) = "/articles/#{a}" } # anonymous, like a route set's
      NAMED = Named.new($helpers, { article: Route.new("/articles/:id(.:format)", [:id], { controller: "articles" }, {}) })
      module Rails
        def self.application = Struct.new(:routes).new(Struct.new(:named_routes).new(NAMED))
      end
      class ViewA; include $helpers; end
      class ViewB; include $helpers; end
      class ViewC; def article_path(a) = "own"; end
      loc = $helpers.instance_method(:article_path).source_location.join(":")
      fact = { "receiver" => "@self", "method" => "article_path", "owner" => nil, "source_location" => loc,
               "visibility" => "public",
               "route" => { "name" => "article", "spec" => "/articles/:id(.:format)", "parts" => ["id"],
                            "defaults" => { controller: "articles" }.inspect } }
      units = [{ "id" => 0, "kind" => "file", "file" => "/x.rb", "pass" => "route/path", "facts" => [fact] }]
      manifest = Lowrail::Manifest.new({ "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
                                         "files" => {}, "units" => units }, "/tmp")
      Lowrail::Guard.install(manifest)
      res = {}
      res[:a] = Lowrail.ok?(0, ViewA)
      res[:b] = Lowrail.ok?(0, ViewB)
      res[:c] = Lowrail.ok?(0, ViewC)             # own method, not the route set's
      res[:cached] = Lowrail::V[0].size
      NAMED.routes[:article] = Route.new("/posts/:id(.:format)", [:id], { controller: "articles" }, {})
      res[:stale_cache] = Lowrail.ok?(0, ViewA)    # no hook fired yet: still cached
      # A redraw redefines the helper (Rails defines it with the same
      # define_method line, so the source location still matches); the
      # method_added hook resets the unit, and revalidation sees the route.
      Lowrail::Guard.reset_method(:article_path)
      res[:spec_changed] = Lowrail.ok?(0, ViewA)
      NAMED.routes[:article] = Route.new("/articles/:id(.:format)", [:id], { controller: "articles" }, { id: /\d+/ })
      Lowrail::Guard.reset_method(:article_path)
      res[:requirements] = Lowrail.ok?(0, ViewA)
      NAMED.routes[:article] = Route.new("/articles/:id(.:format)", [:id], { controller: "articles" }, {})
      Lowrail::Guard.reset_method(:article_path)
      res[:restored] = Lowrail.ok?(0, ViewA)
      $helpers.define_method(:article_path) { |a| a }  # a different definition
      res[:redefined] = Lowrail.ok?(0, ViewA)
      puts JSON.generate(res)
    RUBY
    assert_equal({ "a" => true, "b" => true, "c" => false, "cached" => 3, "stale_cache" => true,
                   "spec_changed" => false, "requirements" => false, "restored" => true, "redefined" => false }, out)
  end
end
