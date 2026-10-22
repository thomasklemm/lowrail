# frozen_string_literal: true

# ruby [--yjit|--zjit] preload_links.rb RAILS_CHECKOUT snapshot|sample
require "json"
require "digest"
rails, command = ARGV
abort "usage: preload_links.rb RAILS_CHECKOUT snapshot|sample" unless %w[snapshot sample].include?(command)
%w[activesupport activemodel actionpack actionview].each { $LOAD_PATH.unshift File.join(rails, _1, "lib") }
require "action_controller"
require "action_view"
require "rack/mock"

class PreloadView < ActionView::Base
  attr_accessor :request, :response, :nonces

  def content_security_policy_nonce
    nonces << nonces.size
    "nonce-#{nonces.size}"
  end
end

view = PreloadView.empty
view.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("https://example.test/"))
view.response = ActionDispatch::Response.new
view.assign_controller(Struct.new(:response).new(view.response))
raise "response header path unavailable" unless view.respond_to?(:response) && view.response
view.nonces = []
hints = []
view.request.set_header("rack.early_hints", ->(headers) { hints << headers.dup })
ActionView::Helpers::AssetTagHelper.preload_links_header = true

reset = -> {
  view.response.headers.delete("link")
  view.nonces.clear
  hints.clear
}
scenarios = {
  style_default: [:stylesheet_link_tag, ["/assets/style.css"], {}],
  style_all: [:stylesheet_link_tag, ["/assets/style.css"], { crossorigin: "use-credentials", integrity: "sha256-asymmetric", nonce: true }],
  script_default: [:javascript_include_tag, ["/assets/app.js"], {}],
  script_all: [:javascript_include_tag, ["/assets/app.js"], { crossorigin: true, integrity: "sha384-distinct", nonce: true }],
  module_script: [:javascript_include_tag, ["/assets/module.js"], { type: :module, crossorigin: "anonymous" }],
  style_three: [:stylesheet_link_tag, %w[/one.css /two.css /three.css], { crossorigin: true, integrity: "sha256-three" }],
  no_nopush: [:stylesheet_link_tag, ["/assets/style.css"], { nopush: false }],
  disabled_control: [:stylesheet_link_tag, ["/assets/style.css"], { preload_links_header: false }],
  deferred_control: [:javascript_include_tag, ["/assets/app.js"], { defer: true }]
}

if command == "snapshot"
  # Cross-products distinguish append order, missing branches, ownership and
  # encoding from a change that merely preserves a single default ASCII case.
  cases = scenarios.values.dup
  %i[stylesheet_link_tag javascript_include_tag].each do |helper|
    [nil, false, true, "anonymous", "use-credentials", "é"].product([nil, "sha256-α"], [nil, false, true], [false, true]).each do |crossorigin, integrity, nonce, nopush|
      cases << [helper, ["/first.asset", "/different.asset", "/first.asset"],
        { crossorigin: crossorigin, integrity: integrity, nonce: nonce, nopush: nopush }]
    end
    %w[UTF-8 ASCII-8BIT ISO-8859-1 UTF-16LE].each do |encoding|
      integrity = encoding == "ASCII-8BIT" ? "é".b : "é".encode(encoding)
      cases << [helper, ["/asset"], { integrity: integrity, crossorigin: "use-credentials", nonce: true }]
    end
    cases << [helper, ["data:text/plain,hello"], { nonce: true }]
    cases << [helper, ["/" + "a" * 1100, "/short"], { nonce: true }]
  end
  encode = ->(s) { s && [s.bytes, s.encoding.name, s.class.name, s.frozen?, s.respond_to?(:html_safe?) && s.html_safe?] }
  snapshots = cases.map do |helper, sources, options|
    reset.call
    saved = Marshal.dump([sources, options])
    begin
      output = view.public_send(helper, *sources, options)
      result = ["ok", encode.call(output), encode.call(view.response.headers["link"]), hints.map { encode.call(_1["link"]) }, view.nonces.dup]
    rescue StandardError => error
      result = [error.class.name, error.message, encode.call(view.response.headers["link"]), hints.map { encode.call(_1["link"]) }, view.nonces.dup]
    end
    raise "caller input mutated" unless saved == Marshal.dump([sources, options])
    result
  end
  puts JSON.generate(snapshots)
else
  yjit = RubyVM::YJIT.enabled?
  zjit = defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
  stats = -> { yjit ? RubyVM::YJIT.runtime_stats : (zjit ? RubyVM::ZJIT.stats : {}) }
  rows = scenarios.to_h do |name, (helper, sources, options)|
    operation = -> { reset.call; view.public_send(helper, *sources, options); nil }
    run = ->(n) { n.times { operation.call } }
    run.call(20_000)
    GC.start
    before = GC.stat(:total_allocated_objects)
    run.call(5_000)
    objects = (GC.stat(:total_allocated_objects) - before).fdiv(5_000)
    GC.start
    jit_before = stats.call
    before = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    run.call(20_000)
    elapsed = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - before
    jit_after = stats.call
    [name, { cpu_ns: elapsed * 1e9 / 20_000, objects: objects,
      jit_delta: jit_after.to_h.filter_map { |key, value| [key, value - jit_before.fetch(key, 0)] if value.is_a?(Numeric) }.to_h }]
  end
  puts JSON.generate(ruby: RUBY_DESCRIPTION, yjit: yjit, zjit: !!zjit,
    source_sha256: Digest::SHA256.file(File.join(rails, "actionview/lib/action_view/helpers/asset_tag_helper.rb")).hexdigest,
    samples: rows)
end
