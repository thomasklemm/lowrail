get "/articles"
get "/articles", name: "probe", env: { "REQUEST_METHOD" => "POST" }, params: { article: { title: "probe", body: "A probe that is long enough." } }, expect: [200, 302, 422]
