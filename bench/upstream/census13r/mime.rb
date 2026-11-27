$LOAD_PATH.unshift(*%w[activesupport actionpack].map { "/home/user/w/rails-main/#{_1}/lib" })
require "action_dispatch"
require "action_dispatch/http/mime_type"
CHROME = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
FIREFOX = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
h = ENV["CASE"] == "firefox" ? FIREFOX : CHROME
$op = -> { Mime::Type.parse(h) }
