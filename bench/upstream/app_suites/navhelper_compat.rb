require "action_view"
class LinkPresenter
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::NavigationHelper if defined?(ActionView::Helpers::NavigationHelper)
end
o = LinkPresenter.new
puts "Rails #{ActionView.version}: #{o.link_to("Issues", "/issues")} button_to=#{o.respond_to?(:button_to)} current_page?=#{o.respond_to?(:current_page?)}"
