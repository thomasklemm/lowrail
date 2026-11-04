require "action_controller"
R = Random.new(7)
VALS = ["", " ", "a", "a/b", "a.b", "1.json", "ü", "%2F", "a b", "?", "#", "..", ".", "-", "a+b", "[x]", 0, 1, -1, 2**70, 1.5, nil, true, false, :sym, [], ["a", "b"], ["", "x"], { a: 1 }] +
  Array.new(400) { Array.new(R.rand(0..6)) { "aZ09 /._-~%?#&=+ü".chars.sample(random: R) }.join }
Obj = Struct.new(:to_param)
VALS.concat(VALS.first(29).map { Obj.new(_1.to_s) })
rs = ActionDispatch::Routing::RouteSet.new
rs.draw do
  resources(:posts) { resources :comments; get :preview, on: :member }
  get "pages/:slug", to: "pages#show", as: :page, constraints: { slug: /[a-z0-9\-]+/ }
  get "files/*path", to: "files#show", as: :file, format: false
  get "search(/:page)", to: "search#index", as: :search
  scope("(:locale)", locale: /en|de/) { get "localized/:id", to: "localized#show", as: :localized }
  get "r/:a/:b", to: "r#show", as: :two, format: false
end
rs.default_url_options = { host: "www.example.com" }
h = Class.new { include rs.url_helpers }.new
helpers = { post_path: 1, preview_post_path: 1, post_comment_path: 2, post_comments_path: 1, page_path: 1, file_path: 1, search_path: 1, localized_path: 1, two_path: 2, post_url: 1 }
helpers.each do |m, n|
  VALS.each_with_index do |v, i|
    args = Array.new(n) { |k| k.zero? ? v : VALS[(i * 7 + k) % VALS.size] }
    r = begin; h.public_send(m, *args).inspect; rescue => e; "!#{e.class}"; end
    puts "#{m}/#{i}\t#{r}"
  end
end
