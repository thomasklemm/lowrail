# frozen_string_literal: true

# INRP1 body numbers: the contacts index and the dashboard (merge, two deferred groups, optional), as Inertia XHR
# visits straight to the controller action.
ENV["INERTIA_BENCH_WORKLOADS"] = "action_xhr,action_dashboard_xhr"
load File.expand_path("app.rb", __dir__)
