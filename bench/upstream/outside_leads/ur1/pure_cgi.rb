# ruby -r ./pure_cgi.rb ...: loads cgi/escape, then removes its C methods so CGI runs the Ruby versions cgi ships
# (CGI::Escape in cgi 0.5 / Ruby 4.0, CGI::Util before), as on TruffleRuby. Load it before uri.
require "cgi/escape"
require "cgi/util" unless CGI::Escape.instance_method(:unescape).source_location
native = defined?(CGI::EscapeExt) && CGI::EscapeExt.instance_methods(false).any? ? CGI::EscapeExt : CGI::Escape
native.instance_methods(false).each { |m| native.send(:remove_method, m) if native.instance_method(m).source_location.nil? }
%i[unescape unescapeURIComponent].each { |m| abort "#{m} still native" unless CGI.method(m).source_location }
