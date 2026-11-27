# Setup for ir.sh: URI's www-form component decoder and encoder as shipped, and the one-copy decoder (UR1).
require "uri"
module UR1
  def self.decode(str, enc = Encoding::UTF_8)
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
    str = str.b
    str.gsub!(/\+|%\h\h/, URI::TBLDECWWWCOMP_)
    str.force_encoding(enc)
  end
end
INPUTS = {
  "plain" => "hello",
  "key" => "article%5Btitle%5D",
  "spaces" => "Hello+world+from+Rack",
  "cookie" => (("A" * 200) + "--" + ("b" * 40) + "%3D%3D"),
}
S = INPUTS.fetch(ENV.fetch("IN"))
