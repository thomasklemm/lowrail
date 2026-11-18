# Diagnostic only: test the proposed fixes without changing the reviewed Rack checkout.
require "rack/utils"

fallback = Module.new do
  def unescape(string, encoding = Encoding::UTF_8)
    return URI.decode_www_form_component(string, encoding) unless String === string && string.instance_of?(String)
    raise ArgumentError, "invalid %-encoding (#{string})" if /%(?!\h\h)/.match?(string)
    CGI.unescape(string, Encoding::BINARY).force_encoding(encoding)
  end
end
Rack::Utils.singleton_class.prepend(fallback)
Rack::QueryParser.prepend(fallback)
Rack::Utils.singleton_class.prepend(Module.new do
  def escape(string)
    return URI.encode_www_form_component(string) unless String === string && string.instance_of?(String) && string.encoding.ascii_compatible?
    super
  end
end)
load File.expand_path("review_exactness.rb", __dir__)
