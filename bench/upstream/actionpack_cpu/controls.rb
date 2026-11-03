# Behavior controls for P1-1 and P1-2; prints observable results. RAILS=path ruby controls.rb
rails = ENV.fetch("RAILS")
%w[activesupport actionpack actionview].each { |f| $LOAD_PATH.unshift File.join(rails, f, "lib") }
require "useragent"; require "action_controller"; require "action_controller/metal/allow_browser"
class A < ActionController::Base; protect_from_forgery with: :exception; end
class B < A; self.allow_forgery_protection = false; end
req = ActionDispatch::TestRequest.create
mk = ->(k) { c = k.new; c.set_request!(req); c }
out = []
a = mk.(A); out << [:a_default, a.allow_forgery_protection, a.send(:protect_against_forgery?), a.forgery_protection_verification_strategy]
a.allow_forgery_protection = false; out << [:a_after_instance_write, a.allow_forgery_protection, a.send(:protect_against_forgery?), A.allow_forgery_protection, mk.(A).allow_forgery_protection]
b = mk.(B); out << [:b_subclass, b.allow_forgery_protection, b.send(:protect_against_forgery?)]
c = mk.(A); c.allow_forgery_protection; A.allow_forgery_protection = false; out << [:class_change_after_read, c.allow_forgery_protection]; A.allow_forgery_protection = true
d = mk.(A); d.config.per_form_csrf_tokens = true; out << [:write_via_config, d.per_form_csrf_tokens, mk.(A).per_form_csrf_tokens]
e = mk.(A); e.request_forgery_protection_token = :tok; out << [:token, e.request_forgery_protection_token, mk.(A).request_forgery_protection_token]
BB = ActionController::AllowBrowser.const_get(:BrowserBlocker)
R = Struct.new(:user_agent)
{ "ff140" => "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
  "ff100" => "Mozilla/5.0 (X11; Linux x86_64; rv:100.0) Gecko/20100101 Firefox/100.0",
  "chrome100" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36",
  "ie11" => "Mozilla/5.0 (Windows NT 10.0; Trident/7.0; rv:11.0) like Gecko",
  "none" => nil }.each do |k, ua|
  h = { firefox: 130 }; s = { "chrome" => 101 }
  out << [:ua, k, BB.new(R.new(ua), versions: :modern).blocked?, BB.new(R.new(ua), versions: h).blocked?, BB.new(R.new(ua), versions: s).blocked?]
end
h = { firefox: 90 }; ua = R.new("Mozilla/5.0 (X11; Linux x86_64; rv:100.0) Gecko/20100101 Firefox/100.0")
before = BB.new(ua, versions: h).blocked?; h[:firefox] = 110; out << [:custom_hash_mutated, before, BB.new(ua, versions: h).blocked?]
out.each { puts _1.inspect }
