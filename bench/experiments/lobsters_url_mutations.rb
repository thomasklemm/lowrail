# frozen_string_literal: true

# Run inside the unchanged disposable production app with its external bundle
# and copied DATABASE_URL. All mutations are confined to forked probe children;
# never write app/config sources or use this observer in a timed worker.
require "json"
require File.expand_path("config/environment", Dir.pwd)
require_relative "lobsters_url_program"

routes = Rails.application.routes
target = routes.url_helpers
invoke = ->(name) { name == :root_url ? target.public_send(name, host: "live.test", protocol: "https") : target.public_send(name) }
LobstersUrlProgram.discover { %i[root_path root_url].each { invoke.call(_1) } }
LobstersUrlProgram.compile(coverage: true, guarded: true)
root = routes.named_routes.get(:root)
helper_class = LobstersUrlProgram.programs.find { _1[:route].to_s == "root" }.fetch(:helper).class

mutations = {
  "redraw" => ->(name) { routes.draw { get "/redrawn", to: "home#index", as: :root } },
  "reload" => ->(name) { Rails.application.reload_routes! },
  "generated_helper" => ->(name) { target.define_singleton_method(name) { |*| "replacement-helper" } },
  "generated_visibility" => ->(name) { target.singleton_class.send(:private, name) },
  "url_for" => ->(name) { routes.define_singleton_method(:url_for) { |*| "replacement-url-for" } },
  "url_for_visibility" => ->(name) { routes.singleton_class.send(:private, :url_for) },
  "http_url_for" => ->(name) { ActionDispatch::Http::URL.define_singleton_method(:url_for) { |options| options.keys.inspect } },
  "http_path_for" => ->(name) { ActionDispatch::Http::URL.define_singleton_method(:path_for) { |options| options.keys.inspect } },
  "url_options" => ->(name) { target.define_singleton_method(:url_options) { {host: "other.test", protocol: "http", script_name: "/mounted"} } },
  "url_options_visibility" => ->(name) { target.singleton_class.send(:private, :url_options) },
  "default_url_options" => ->(name) { routes.define_singleton_method(:default_url_options) { {anchor: "new-default"} } },
  "default_visibility" => ->(name) { routes.singleton_class.send(:private, :default_url_options) },
  "script_name" => ->(name) { routes.define_singleton_method(:find_script_name) { |opts| opts.delete(:script_name) || "/live-script" } },
  "format" => ->(name) { root.define_singleton_method(:format) { |*| "/replacement-format" } },
  "suppressed_hook_format" => ->(name) {
    root.define_singleton_method(:singleton_method_added) { |_| }
    root.define_singleton_method(:format) { |*| "/suppressed-hook" }
  },
  "format_structure" => ->(name) { root.instance_variable_get(:@path_formatter).instance_variable_get(:@parts)[0] = "/changed-part" },
  "route_defaults" => ->(name) { root.defaults[:anchor] = "changed-default" },
  "helper_call" => ->(name) { helper_class.define_method(:call) { |*| "replacement-call" } },
  "helper_call_visibility" => ->(name) { helper_class.send(:private, :call) },
  "routes_override" => ->(name) {
    other = ActionDispatch::Routing::RouteSet.new
    other.draw { get "/other-set", to: "home#index", as: :root }
    target.define_singleton_method(:_routes) { other }
  },
  "routes_visibility" => ->(name) { target.singleton_class.send(:private, :_routes) }
}

rows = []
mutations.each do |label, mutation|
  helpers = case label
  when "http_url_for" then [:root_url]
  when "http_path_for" then [:root_path]
  else %i[root_path root_url]
  end
  helpers.product(%w[entry boundary]).each do |name, phase|
    pair = [false, true].map do |on|
      reader, writer = IO.pipe
      pid = fork do
        reader.close
        LobstersUrlProgram.select(on)
        LobstersUrlProgram.counts.clear
        trace = nil
        fired, reads = false, 0
        if phase == "entry"
          mutation.call(name)
        end
        trace = TracePoint.new(:return) do |event|
          next unless event.self.equal?(target) && event.method_id == :url_options
          reads += 1
          if phase == "boundary" && !fired
            fired = true
            mutation.call(name)
          end
        end
        results = []
        trace.enable do
          2.times do
            results << begin
              result = invoke.call(name)
              {"value" => result, "class" => result.class.name, "encoding" => result.encoding.name, "frozen" => result.frozen?}
            rescue StandardError => error
              # Receiver inspection embeds process-local identities in errors.
              # Compare the exception's public class/name, not normalized output
              # pages; screen checks still compare literal full responses.
              {"error" => error.class.name, "name" => error.respond_to?(:name) ? error.name.to_s : nil}
            end
          end
        end
        writer.write(JSON.generate("results" => results, "fired" => fired, "url_options_reads" => reads,
          "counts" => LobstersUrlProgram.counts))
        writer.close
        exit! 0
      end
      writer.close
      data = JSON.parse(reader.read)
      reader.close
      Process.wait(pid)
      raise "probe child failed" unless $?.success?
      data
    end
    observed = %w[results fired url_options_reads]
    raise "mutation mismatch #{[label, name, phase, pair].inspect}" unless pair[0].slice(*observed) == pair[1].slice(*observed)
    raise "boundary not reached" if phase == "boundary" && !pair[1].fetch("fired")
    if phase == "boundary"
      raise "no boundary fallback #{[label, name, pair].inspect}" unless pair[1].fetch("counts").fetch("boundary_fallback", 0) >= 1
    end
    rows << {"mutation" => label, "helper" => name, "phase" => phase, "passed" => true, "arms" => pair}
  end
end

# Values remain live without deoptimization when no method or route fact changed.
LobstersUrlProgram.select(true)
routes.instance_variable_get(:@config).relative_url_root = "/live-mount"
raise "mount frozen" unless target.root_path == "/live-mount/"
%w[one.test two.test].product(%w[http https]).each do |host, protocol|
  raise "host/protocol frozen" unless target.root_url(host: host, protocol: protocol) == "#{protocol}://#{host}/live-mount/"
end
puts JSON.pretty_generate("passed" => true, "pairs" => rows.size, "live_mount_host_protocol" => true, "rows" => rows)
