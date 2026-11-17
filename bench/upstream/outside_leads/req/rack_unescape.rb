require "cgi/escape"
module Rack
  module Utils
    def unescape(s, encoding = Encoding::UTF_8)
      return URI.decode_www_form_component(s, encoding) unless s.instance_of?(String)
      raise ArgumentError, "invalid %-encoding (#{s})" if /%(?!\h\h)/.match?(s)
      CGI.unescape(s, encoding).force_encoding(encoding)
    end
    module_function :unescape
  end
  class QueryParser
    def unescape(s, encoding = Encoding::UTF_8)
      return URI.decode_www_form_component(s, encoding) unless s.instance_of?(String)
      raise ArgumentError, "invalid %-encoding (#{s})" if /%(?!\h\h)/.match?(s)
      CGI.unescape(s, encoding).force_encoding(encoding)
    end
  end
end
