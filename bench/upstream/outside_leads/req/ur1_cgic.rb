# Measurement patch (UR1 rework): the shared _decode_uri_component keeps the check and the `b` copy and decodes
# through a block; decode_www_form_component passes cgi/escape's CGI.unescape, decode_uri_component (not on the
# request path) CGI.unescapeURIComponent. Same bodies as the ruby/uri branch.
require "cgi/escape"
URI.singleton_class.prepend(Module.new do
  def decode_www_form_component(str, enc = Encoding::UTF_8)
    _decode_uri_component(str, enc) {|bytes| CGI.unescape(bytes, Encoding::BINARY) }
  end

  def decode_uri_component(str, enc = Encoding::UTF_8)
    _decode_uri_component(str, enc) {|bytes| CGI.unescapeURIComponent(bytes, Encoding::BINARY) }
  end

  private

  def _decode_uri_component(str, enc)
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
    yield(str.b).force_encoding(enc)
  end
end)
