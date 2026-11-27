$LOAD_PATH.unshift(*%w[activesupport actionpack].map { "/home/user/w/rails-main/#{_1}/lib" })
require "action_dispatch"
require "action_dispatch/http/mime_type"
H = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
T = Mime::Type
SEP = T.singleton_class.const_get(:PARAMETER_SEPARATOR_REGEXP); ACC = T.singleton_class.const_get(:ACCEPT_HEADER_REGEXP)
items = H.scan(ACC)
names = %w[text/html application/xhtml+xml application/xml image/avif image/webp image/apng */* application/signed-exchange;v=b3]
types = names.map { T.lookup(_1) }
$op = case ENV["CASE"]
when "scan" then -> { H.scan(ACC) }
when "split" then -> { items.each { _1.split(SEP) } }
when "lookup" then -> { names.each { T.lookup(_1) } }
when "lookup_known" then -> { %w[text/html application/xml */*].each { T.lookup(_1) } }
when "uniq" then -> { types.dup.uniq! }
when "full" then -> { T.parse(H) }
end
