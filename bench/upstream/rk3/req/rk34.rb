# RK3 plus the RK4 commit's escape, verbatim.
load File.expand_path("rk3.rb", __dir__)
module Rack
  module Utils
    def escape(s)
      return URI.encode_www_form_component(s) unless s.instance_of?(String)

      escaped = CGI.escape(s).force_encoding(Encoding::US_ASCII)
      escaped.gsub!("%2A", "*")
      escaped.gsub!("~", "%7E")
      escaped
    end
    module_function :escape
  end
end
