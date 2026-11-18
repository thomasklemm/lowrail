# RK3 plus the RK4 commit's escape, verbatim.
load File.expand_path("rk3.rb", __dir__)
module Rack
  module Utils
    def escape(s)
      # MRI before 4.0 only defines CGI.escape for ASCII-incompatible strings once cgi/util is loaded.
      return URI.encode_www_form_component(s) unless String === s && s.instance_of?(String) && s.encoding.ascii_compatible?

      escaped = CGI.escape(s).force_encoding(Encoding::US_ASCII)
      escaped.gsub!("%2A", "*")
      escaped.gsub!("~", "%7E")
      escaped
    end
    module_function :escape
  end
end
