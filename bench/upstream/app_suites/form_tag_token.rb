# RAILS=path ruby form_tag_token.rb -> exit 1 if a class that includes only FormTagHelper can't render a POST form
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[actionview activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
end
require "action_view"

class Renderer
  include ActionView::Helpers::FormTagHelper
  attr_accessor :output_buffer
end

begin
  puts Renderer.new.form_tag("/posts", method: :patch) { "" }
  exit 0
rescue NoMethodError => e
  puts e.message
  exit 1
end
