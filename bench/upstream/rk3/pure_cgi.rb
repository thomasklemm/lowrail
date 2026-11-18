# Load with -r to make CGI.escape and CGI.unescape the pure-Ruby versions on MRI before 4.0 (TruffleRuby skips the C
# extension too; JRuby has its own Java implementation).
require "rbconfig"
$LOADED_FEATURES << File.join(RbConfig::CONFIG["archdir"], "cgi/escape.so")
require "cgi/util"
abort "C escape still loaded" if defined?(CGI::Escape)
