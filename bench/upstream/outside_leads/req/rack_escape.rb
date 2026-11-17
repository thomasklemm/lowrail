require "cgi/escape"
module Rack
  module Utils
    def escape(s)
      r = CGI.escape(s.to_s).force_encoding(Encoding::US_ASCII)
      r.gsub!("%2A", "*") if r.include?("%2A")
      r.gsub!("~", "%7E") if r.include?("~")
      r
    end
    module_function :escape
  end
end
