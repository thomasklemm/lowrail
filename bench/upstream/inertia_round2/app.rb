# frozen_string_literal: true

# A small Inertia app in one process, for script/upstream-bench (`--gems inertia_rails`) and alloc_lines.rb.
# Sizes follow Pingcrm's contacts index and React Starter Kit's dashboard: a shared auth user and flash, a
# 25-row page of records as hashes, filters and pagination links. Requests carry a session cookie and the
# XSRF header, as a browser's would after its first visit. SSR is off.
ENV["RAILS_ENV"] ||= "production" # DevTools record only in development
require "logger"
require "tmpdir"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "inertia_rails"

module InertiaBench
  VIEWS = Dir.mktmpdir("inertia-bench-views")
  FileUtils.mkdir_p(File.join(VIEWS, "layouts"))
  File.write(File.join(VIEWS, "layouts", "application.html.erb"), <<~ERB)
    <!DOCTYPE html>
    <html>
      <head>
        <title>Bench</title>
        <%= csrf_meta_tags %>
      </head>
      <body><%= yield %></body>
    </html>
  ERB

  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.yjit = false # the harness chooses the mode (load_defaults 7.2+ would enable YJIT)
    config.enable_reloading = false
    config.eager_load = false # the controllers below are defined after boot
    config.secret_key_base = "0" * 64
    config.logger = Logger.new(nil)
    config.log_level = :fatal
    config.hosts.clear
    config.consider_all_requests_local = false
    config.action_controller.perform_caching = true
    config.paths["app/views"].unshift(VIEWS)
  end

  ROWS = Array.new(25) do |i|
    { id: i + 1, name: "Contact #{i + 1}", phone: "555-01#{format('%02d', i)}", city: "Springfield",
      organization: { name: "Org #{i % 5}" }, deleted_at: nil }
  end.freeze
  LINKS = Array.new(5) { |i| { url: "/contacts?page=#{i + 1}", label: (i + 1).to_s, active: i.zero? } }.freeze
  USER = { id: 1, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", owner: true,
           account: { id: 1, name: "Acme Corporation" } }.freeze
end

InertiaBench::Application.initialize!

InertiaRails.configure do |config|
  config.version = "8f2a1c"
  config.always_include_errors_hash = true
end

class ApplicationController < ActionController::Base
  inertia_share auth: -> { { user: InertiaBench::USER } }
  inertia_share flash: -> { flash.to_hash }
end

class ContactsController < ApplicationController
  def index
    render inertia: "Contacts/Index", props: {
      filters: { search: params[:search], trashed: params[:trashed] },
      contacts: { data: InertiaBench::ROWS, links: InertiaBench::LINKS },
    }
  end

  # Deferred, optional and merge props next to plain ones, as a dashboard uses them.
  def dashboard
    render inertia: "Dashboard", props: {
      stats: { users: 1200, revenue: 34_500, orders: 87 },
      recent: InertiaRails.merge { InertiaBench::ROWS.first(10) },
      activity: InertiaRails.defer { InertiaBench::ROWS },
      chart: InertiaRails.defer(group: "charts") { Array.new(30) { |i| { day: i, value: i * 3 } } },
      archived: InertiaRails.optional { [] },
    }
  end
end

InertiaBench::Application.routes.draw do
  get "contacts", to: "contacts#index"
  get "dashboard", to: "contacts#dashboard"
end

module InertiaBench
  APP = Application
  first = Rack::MockRequest.env_for("/contacts")
  _, headers, body = APP.call(first)
  body.close if body.respond_to?(:close)
  cookie = Array(headers["set-cookie"] || headers["Set-Cookie"]).join("\n").split("\n")
  COOKIE = cookie.map { |c| c.split(";", 2).first }.join("; ")
  XSRF = cookie.find { |c| c.start_with?("XSRF-TOKEN=") }.to_s.split(";", 2).first.to_s.split("=", 2).last

  BROWSER = { "HTTP_COOKIE" => COOKIE, "HTTP_ACCEPT" => "text/html,application/xhtml+xml",
              "HTTP_USER_AGENT" => "Mozilla/5.0", "HTTP_HOST" => "example.org" }.freeze
  XHR = BROWSER.merge("HTTP_ACCEPT" => "text/html, application/xhtml+xml", "HTTP_X_INERTIA" => "true",
                      "HTTP_X_INERTIA_VERSION" => "8f2a1c", "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
                      "HTTP_X_XSRF_TOKEN" => XSRF).freeze

  WORKLOADS = {
    "html" => ["/contacts", BROWSER],
    "xhr" => ["/contacts", XHR],
    "partial" => ["/contacts", XHR.merge("HTTP_X_INERTIA_PARTIAL_COMPONENT" => "Contacts/Index",
                                         "HTTP_X_INERTIA_PARTIAL_DATA" => "contacts")],
    "dashboard_xhr" => ["/dashboard", XHR],
    "deferred_reload" => ["/dashboard", XHR.merge("HTTP_X_INERTIA_PARTIAL_COMPONENT" => "Dashboard",
                                                  "HTTP_X_INERTIA_PARTIAL_DATA" => "activity")],
  }

  # The same visits straight to the controller action (`action_xhr` and so on): no middleware, and a test session
  # that is already loaded, so the count is mostly the controller, Inertia and JSON. Whole requests vary by about 1%
  # between processes (hash seeds), which hides changes of that size.
  ACTIONS = { "contacts" => ContactsController.action(:index), "dashboard" => ContactsController.action(:dashboard) }.freeze
  # Without the boot request's cookie and token: their encrypted, random bytes change how much decoding each process
  # does (about 1% of the instructions), so the A/A would differ by that much.
  FIXED = { "HTTP_COOKIE" => nil, "HTTP_X_XSRF_TOKEN" => "bench" }.freeze
  WORKLOADS.keys.each do |name|
    path, headers = WORKLOADS[name]
    WORKLOADS["action_#{name}"] = [path, headers.merge(FIXED.slice(*headers.keys)).compact.freeze]
  end
  WORKLOADS.freeze

  def self.call(name)
    path, headers = WORKLOADS.fetch(name)
    env = Rack::MockRequest.env_for(path, headers.dup)
    app = APP
    if name.start_with?("action_")
      require "action_controller/test_case"
      action = path.delete_prefix("/")
      env["rack.session"] = ActionController::TestSession.new
      env["action_dispatch.request.path_parameters"] = { controller: "contacts", action: action == "contacts" ? "index" : action }
      app = ACTIONS.fetch(action)
    end
    status, _, body = app.call(env)
    body.each { |_| }
    body.close if body.respond_to?(:close)
    raise "#{name}: #{status}" unless status == 200

    status
  end

  WORKLOADS.each_key { |name| call(name) }
end

if defined?(UpstreamBench)
  # INERTIA_BENCH_WORKLOADS=xhr,dashboard_xhr limits the reports (each Callgrind window boots the app under Valgrind).
  names = ENV.fetch("INERTIA_BENCH_WORKLOADS", InertiaBench::WORKLOADS.keys.join(",")).split(",")
  names.each { |name| UpstreamBench.report(name) { InertiaBench.call(name) } }
end
