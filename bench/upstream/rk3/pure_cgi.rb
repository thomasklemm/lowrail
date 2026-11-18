# Load with -r to make CGI.escape and CGI.unescape the pure-Ruby versions (as on JRuby and TruffleRuby).
require "rbconfig"
$LOADED_FEATURES << File.join(RbConfig::CONFIG["archdir"], "cgi/escape.so")
require "cgi/util"
abort "C escape still loaded" if defined?(CGI::Escape)
