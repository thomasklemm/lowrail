# Loaded before uri: gives CGI a Ruby-defined unescapeURIComponent, as TruffleRuby's pure-Ruby cgi/escape.
require "cgi/escape"
def CGI.unescapeURIComponent(string, encoding = Encoding::UTF_8)
  str = string.b
  str.gsub!(/((?:%[0-9a-fA-F]{2})+)/) { |m| [m.delete("%")].pack("H*") }
  str.force_encoding(encoding)
  str.valid_encoding? ? str : str.force_encoding(string.encoding)
end
