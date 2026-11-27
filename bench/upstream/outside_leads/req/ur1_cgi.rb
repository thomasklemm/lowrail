# Measurement patch (UR1-cgi): URI.decode_www_form_component hands plain ASCII-compatible Strings to cgi/escape's
# C CGI.unescape (RK3's guard and encoding handling); everything else decodes as before. Not decode_uri_component,
# which leaves "+" alone.
require "cgi/escape"
URI.singleton_class.prepend(Module.new do
  def decode_www_form_component(str, enc = Encoding::UTF_8)
    return super unless str.instance_of?(String) && str.encoding.ascii_compatible?
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
    CGI.unescape(str, Encoding::BINARY).force_encoding(enc)
  end
end)
