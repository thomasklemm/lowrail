# Setup for ir.sh: as micro.rb, plus a decoder that hands Strings to cgi/escape's C CGI.unescape (UR1-cgi),
# with RK3's guard and encoding handling.
load File.expand_path("micro.rb", __dir__)
require "cgi/escape"
module UR1
  def self.decode_cgi(str, enc = Encoding::UTF_8)
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
    return decode(str, enc) unless str.instance_of?(String) && str.encoding.ascii_compatible?
    CGI.unescape(str, Encoding::BINARY).force_encoding(enc)
  end
end
