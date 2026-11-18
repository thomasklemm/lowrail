# The RK3 branch's methods, verbatim, over rack 3.2.7 (whose escape and unescape match rack main).
require "cgi/escape"
module Rack
  module Utils
    def unescape(s, encoding = Encoding::UTF_8)
      return URI.decode_www_form_component(s, encoding) unless String === s && s.instance_of?(String)

      raise ArgumentError, "invalid %-encoding (#{s})" if /%(?!\h\h)/.match?(s)
      CGI.unescape(s, Encoding::BINARY).force_encoding(encoding)
    end
    module_function :unescape
  end

  class QueryParser
    private def unescape(string, encoding = Encoding::UTF_8)
      return URI.decode_www_form_component(string, encoding) unless String === string && string.instance_of?(String)

      raise ArgumentError, "invalid %-encoding (#{string})" if /%(?!\h\h)/.match?(string)
      CGI.unescape(string, Encoding::BINARY).force_encoding(encoding)
    end
  end
end
