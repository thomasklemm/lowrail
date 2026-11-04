R = ROUTES.named_routes[:post]
PRM = { id: "123" }
CASES["evaluate"] = -> { R.format(PRM) }
CASES["escape_seg"] = -> { ActionDispatch::Journey::Router::Utils.escape_segment("123") }
CASES["noop"] = -> { nil }
p R.path.spec.to_s, R.instance_variable_get(:@path_formatter) if ENV["SHOW"]
