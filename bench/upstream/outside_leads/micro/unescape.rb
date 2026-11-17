require "uri"
module Alt
  RE = /\+|%\h\h/
  def self.rack_fast(s, enc = Encoding::UTF_8)
    if s.ascii_only? && !s.include?("%") && !s.include?("+")
      s.b.force_encoding(enc)
    else
      URI.decode_www_form_component(s, enc)
    end
  end
  def self.uri_bang(str, enc = Encoding::UTF_8)
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
    str = str.b
    str.gsub!(RE, URI::TBLDECWWWCOMP_)
    str.force_encoding(enc)
  end
end
INPUTS = {
  "plain" => "hello",
  "int" => "42",
  "key" => "article%5Btitle%5D",
  "spaces" => "Hello+world+from+Rack",
  "cookie" => ("A" * 200) + "--" + ("b" * 40) + "%3D%3D",
}
S = INPUTS.fetch(ENV.fetch("IN"))
require "cgi/escape"
module Alt
  def self.cgi(str, enc = Encoding::UTF_8)
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
    CGI.unescape(str, enc)
  end
end
