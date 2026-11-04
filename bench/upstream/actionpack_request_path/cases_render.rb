CASES["all_renderers"] = -> { C._all_renderers }
CASES["view_assigns"] = -> { C.view_assigns }
CASES["rbwr"] = -> { C._render_to_body_with_renderer({template: "x"}) }
%w[@post @posts @comments @user @title @page @q @filter].each_with_index { |iv, i| C.instance_variable_set(iv, i) }
p C.class._renderers, ActionController::Renderers.all if ENV["SHOW"]
PI = C.send(:_protected_ivars)
CASES["ivars"] = -> { C.instance_variables }
CASES["ivars_diff"] = -> { C.instance_variables - PI }
CASES["noop"] = -> { nil }
p C.instance_variables.size, PI.size, (C.instance_variables - PI) if ENV["SHOW"]
JH = { id: 1, title: "x" }
CASES["render_json"] = -> { C.render_to_body(json: JH) }
