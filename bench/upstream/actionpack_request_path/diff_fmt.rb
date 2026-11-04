# Differential for Journey::Format: route generation output (value, encoding, frozen, errors) for many specs/inputs.
# RAILS=<worktree> ruby [jit flags] diff_fmt.rb > out
require "bundler/setup"
RAILS = ENV.fetch("RAILS")
%w[activesupport actionpack actionview activemodel].each { |c| $LOAD_PATH.unshift File.join(RAILS, c, "lib") }
require "action_controller"

SPECS = [
  "/", "/posts", "/posts/:id(.:format)", "/posts/:post_id/comments/:id(.:format)", "/pages/:slug",
  "/files/*path", "/files/*path(.:format)", "/a/b/c/:x(/:y(/:z))(.:format)", "/café/:id", "/caf\u00e9/\u2713/:id(.:format)",
  "/x\\:y/:id", "/v1.0/items/:id", "(/:locale)/about(.:format)", "/foo-bar_baz~!$&'*+,;=@/:id", "/search/:q.:format",
  "/:a-:b", "/static/path/only", "/static/path/only(.:format)", "*all", "/with space/:id", "/%E2%9C%93/:id",
  "/a(/b(/c(/:d)))", "/a/(b/)c/:id", "/:controller(/:action(/:id))(.:format)", "/x/:y/z(/w/:v/u)(.:format)",
  "/((a)b)c/:id", "/:id/edit(.:format)", "/a.b.c/:d.:e", "/a/b/c/d/e/f/g/h/:i",
  "/caf\xC3\xA9/:id".b, "/ascii/:id".encode("US-ASCII"), "/\u00e9\u00e8/(\u00ea/):id",
]
P = Struct.new(:v) { def to_param = v; def to_s = v.to_s }
class Sub < String; end
VALUES = [nil, "", "1", "abc", "a b", "a/b", "é", "\u2713", "caf\xC3\xA9".b, "x".encode("US-ASCII"), 7, :sym,
  Sub.new("sub"), "a.b", "%", "a?b#c", "\u00e9".encode("ISO-8859-1"), "\xFF".b]
KEYS = %i[id post_id slug path x y z locale q format a b d e v i controller action]

def show(v)
  case v
  when String then "#{v.inspect}:#{v.encoding}:#{v.frozen?}:#{v.class}"
  else v.inspect
  end
end

ITER = Integer(ENV["ITER"] || 30)
out = []
SPECS.each_with_index do |spec, si|
  begin
    node = ActionDispatch::Journey::Parser.parse(spec)
    fmt = ActionDispatch::Journey::Visitors::FormatBuilder.new.accept(node)
  rescue => e
    out << "#{si} build #{e.class}: #{e.message}"
    next
  end
  names = spec.b.scan(/[:*](\w+)/).flatten.map(&:to_sym).uniq
  rng = Random.new(si)
  combos = []
  combos << names.to_h { |n| [n, "v#{n}"] }
  combos << {}
  40.times { combos << names.to_h { |n| [n, VALUES[rng.rand(VALUES.size)]] }.reject { rng.rand < 0.2 } }
  combos << KEYS.to_h { |k| [k, "k"] }
  combos.each_with_index do |h, ci|
    res = nil
    ITER.times do
      res = begin
        show(fmt.evaluate(h))
      rescue => e
        "#{e.class}: #{e.message}"
      end
    end
    out << "#{si} #{ci} #{h.map { |k, v| "#{k}=#{show(v)}" }.join(",")} => #{res}"
  end
end

# Through a route set: named helpers (optimized and general path) and url_for.
routes = ActionDispatch::Routing::RouteSet.new
routes.draw do
  resources(:posts) { resources :comments }
  get "/pages/:slug", to: "pages#show", as: :page
  get "/files/*path", to: "files#show", as: :file
  get "/caf\u00e9/:id(.:format)", to: "cafe#show", as: :cafe
  get "/a/b/c/:x(/:y(/:z))", to: "abc#show", as: :abc
  scope "(:locale)" do
    get "/about", to: "pages#about", as: :about
  end
  get "/static/only", to: "pages#static", as: :static
  root "posts#index"
end
ctx = Class.new { include routes.url_helpers; def default_url_options = { host: "example.com" } }.new
calls = [
  -> { ctx.post_path(1) }, -> { ctx.post_path("a b") }, -> { ctx.post_path(1, format: :json) }, -> { ctx.post_url(5) },
  -> { ctx.post_comment_path(1, 2) }, -> { ctx.post_comment_path(1, 2, q: "x") }, -> { ctx.page_path("é") },
  -> { ctx.file_path("a/b c/d") }, -> { ctx.cafe_path(3) }, -> { ctx.cafe_url(3, format: "json") },
  -> { ctx.abc_path(1) }, -> { ctx.abc_path(1, 2) }, -> { ctx.abc_path(1, 2, 3) }, -> { ctx.abc_path(x: 1, z: 3) },
  -> { ctx.about_path }, -> { ctx.about_path(locale: "de") }, -> { ctx.static_path }, -> { ctx.static_path(format: :xml) },
  -> { ctx.root_path }, -> { ctx.root_url(anchor: "x") }, -> { ctx.posts_path(page: 2) },
  -> { ctx.url_for(controller: "posts", action: "show", id: 9, only_path: true) },
  -> { ctx.url_for(controller: "comments", action: "index", post_id: 9) }, -> { ctx.post_path(nil) }, -> { ctx.post_path("") },
]
calls.each_with_index do |c, i|
  res = nil
  ITER.times do
    res = begin
      show(c.())
    rescue => e
      "#{e.class}: #{e.message}"
    end
  end
  out << "call #{i} => #{res}"
end
puts out
