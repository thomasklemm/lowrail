# frozen_string_literal: true

# edge_probe.rb: the opus review's edge probe for K6, beside widen.rb. Prints
# button_to's output (or the exception) for the edges the review asked about:
# html_safe keys and values, to_param returning a SafeBuffer, the form option,
# remove_hidden_field_autocomplete both ways, params with the method and token
# fields, Turbo and Rails UJS data attributes, and keys or values that need
# escaping, including invalid UTF-8. Run on two trees and diff.
rails = ENV.fetch("RAILS")
%w[activesupport actionview actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "action_view"
require "action_controller"

class View < ActionView::Base
  def protect_against_forgery? = true
  def form_authenticity_token(form_options: {}) = "tok<&>\"#{form_options[:method]}"
  def request_forgery_protection_token = :authenticity_token
end
V = View.empty
V.output_buffer = ActionView::OutputBuffer.new
SafeParam = Struct.new(:s) { def to_param = s }

params = {
  "safe key" => { "<b>k</b>".html_safe => "v" },
  "safe nested key" => { "o" => { "<i>".html_safe => "v" } },
  "safe value" => { "k" => "<b>\"v\"</b>".html_safe },
  "unsafe value" => { "k" => "<b>\"v\"</b>&amp;'" },
  "to_param SafeBuffer" => { "k" => SafeParam.new("<x a=\"1\">".html_safe) },
  "to_param unsafe" => { "k" => SafeParam.new("<x a=\"1\">") },
  "key with quote and brackets" => { "a\"]b[c" => "v", "<k>" => { "&" => ["<", nil, false] } },
  "invalid utf-8 key" => { "k\xffx".dup.force_encoding("UTF-8") => "v" },
  "invalid utf-8 value" => { "k" => "v\xffx".dup.force_encoding("UTF-8") },
  "binary key with space" => { "a b\xff".b => "v" },
  "key named like attributes" => { "hidden" => "h", "data" => "d", "class" => "c", "aria" => "a", "type" => "t", "id" => "i" },
}
options = {
  "plain" => {},
  "method delete" => { method: :delete },
  "method patch + form" => { method: "PATCH", form: { id: "f", class: "fc", data: { turbo_frame: "_top", controller: "x" } } },
  "turbo" => { method: :delete, data: { turbo_method: :delete, turbo_confirm: "Sure?" }, form: { data: { turbo: false } } },
  "ujs" => { method: :delete, remote: true, data: { confirm: "Sure?", disable_with: "..." } },
  "token given" => { authenticity_token: "<given>" },
  "token false" => { authenticity_token: false, method: :put },
  "get" => { method: :get },
  "form method override" => { form: { method: :put } },
  "form_class" => { form_class: "x", form: { "data-turbo" => "false" } },
}

[false, true].each do |rhfa|
  ActionView::Base.remove_hidden_field_autocomplete = rhfa
  [false, true].each do |tag_button|
    ActionView::Helpers::NavigationHelper.button_to_generates_button_tag = tag_button
    params.each do |pl, pv|
      options.each do |ol, ov|
        label = "rhfa=#{rhfa} button_tag=#{tag_button} | #{pl} | #{ol}"
        r = begin
          out = V.button_to("Go", "/p", **ov, params: pv)
          "#{out.class} safe=#{out.html_safe?} enc=#{out.encoding} valid=#{out.valid_encoding?}\n  #{out.b.inspect}"
        rescue Exception => e
          "raise #{e.class}: #{e.message.b.inspect}"
        end
        puts label, "  #{r}"
      end
    end
  end
end
