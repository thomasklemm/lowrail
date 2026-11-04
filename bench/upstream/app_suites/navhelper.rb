require "action_view"
class OnlyUrlHelper
  include ActionView::Helpers::UrlHelper
end
class WithNavigationHelper
  include ActionView::Helpers::NavigationHelper
end
[OnlyUrlHelper, WithNavigationHelper].each do |k|
  r = begin
    o = k.new
    [o.link_to("Issues", "/issues"), o.respond_to?(:button_to), o.respond_to?(:current_page?), o.mail_to("a@b.c")].inspect
  rescue => e
    "#{e.class}: #{e.message[0, 60]}"
  end
  puts "#{k}: #{r}"
end
