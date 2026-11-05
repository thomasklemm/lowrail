# RAILS=path ruby form_helper_link_to.rb
# cells-rails' Cell::ViewModel includes ActionView::Helpers::FormHelper (cells-rails 0.1.6, lib/cell/railtie.rb#L49)
# and gets link_to through it on 8.1. On main link_to lives in NavigationHelper, which FormHelper doesn't include,
# so a cell's link_to falls through to Decidim::ViewModel#method_missing and the controller's view context, whose
# capture escapes the cell's raw block output. This prints what such a class responds to.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[actionview activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
end
require "action_view"

class CellLike
  include ActionView::Helpers::FormHelper
end

c = CellLike.new
puts({ link_to: c.respond_to?(:link_to), button_to: c.respond_to?(:button_to), mail_to: c.respond_to?(:mail_to) }.inspect)

view = ActionView::Base.empty
raw_block_output = "<div>card</div>" # what cells-erb's capture returns: a plain String, not html_safe
puts view.link_to("/x") { raw_block_output }
