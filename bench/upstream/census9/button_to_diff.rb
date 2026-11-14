# frozen_string_literal: true

# button_to_diff.rb: prints button_to's output (or exception) for a grid of
# inputs, for a Rails checkout in RAILS. Run on two trees and diff the files.
# Covers names, URLs (String, Hash, false), method, params (flat, nested,
# Arrays, HTML characters), form and form_class, remote, authenticity_token,
# blocks, data and disabled options, button_to_generates_button_tag,
# remove_hidden_field_autocomplete, and forgery protection on and off.
rails = ENV.fetch("RAILS")
%w[activesupport actionview actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "action_view"
require "action_controller"

ROUTES = ActionDispatch::Routing::RouteSet.new
ROUTES.draw { resources(:posts) }
class View < ActionView::Base
  include ROUTES.url_helpers
  def default_url_options = { only_path: true }
end
class CsrfView < View
  def protect_against_forgery? = true
  def form_authenticity_token(form_options: {}) = "tok-#{form_options[:method]}-#{form_options[:action]}"
  def request_forgery_protection_token = :authenticity_token
end
class NoEmbedView < CsrfView
  def embed_authenticity_token? = false
end

names = ["Go", "<b>&", nil]
urls = ["/posts/1", { controller: "posts", action: "show", id: 1 }, false, "javascript:alert(1)"]
html = [
  {}, { method: :delete }, { method: "PATCH" }, { method: :get }, { method: :post }, { method: "" }, { method: nil },
  { params: { a: 1, "b" => "<x>", c: [1, 2], d: { e: "f" } } }, { params: {} },
  { form: { multipart: true, "data-turbo" => "false", id: "f" } }, { form: { class: "c", method: :put } }, { form_class: "fc" },
  { remote: true }, { remote: true, authenticity_token: "given" }, { authenticity_token: false }, { authenticity_token: "t" },
  { authenticity_token: true }, { class: "btn", data: { confirm: "Sure?", disable_with: "..." }, disabled: true },
  { "method" => :delete, "form" => { "class" => "s" } }, { method: :delete, params: { id: 1 }, form: { data: { x: 1 } } },
]
out = []
[View, CsrfView, NoEmbedView].each do |klass|
  view = klass.empty
  view.output_buffer = ActionView::OutputBuffer.new
  [false, true].each do |tag_flag|
    ActionView::Helpers::NavigationHelper.button_to_generates_button_tag = tag_flag
    [false, true].each do |no_autocomplete|
      ActionView::Base.remove_hidden_field_autocomplete = no_autocomplete
      names.product(urls, html).each do |name, url, opts|
        [false, true].each do |block|
          label = [klass, tag_flag, no_autocomplete, name, url, opts, block].inspect
          result = begin
            o = opts.deep_dup
            block ? view.button_to(url, o) { name.to_s } : view.button_to(name, url, o)
          rescue => e
            "#{e.class}: #{e.message}"
          end
          out << "#{label}\n  #{result}\n  html_safe=#{result.html_safe?}"
        end
      end
    end
  end
end
puts out
warn "#{out.size} cases"
