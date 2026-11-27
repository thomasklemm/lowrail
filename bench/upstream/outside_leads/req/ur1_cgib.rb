# Measurement patch (UR1 head cecaed1): URI.decode_www_form_component keeps its check and `b` copy and replaces
# only the gsub with cgi/escape's C CGI.unescape on the BINARY copy.
require "cgi/escape"
URI.singleton_class.prepend(Module.new do
  def decode_www_form_component(str, enc = Encoding::UTF_8)
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
    CGI.unescape(str.b, Encoding::BINARY).force_encoding(enc)
  end
end)
