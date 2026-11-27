# Loaded before uri: hides cgi/escape's unescapeURIComponent, as on cgi before 0.3.3.
require "cgi/escape"
CGI.singleton_class.ancestors.each { |m| m.send(:remove_method, :unescapeURIComponent) if m.instance_methods(false).include?(:unescapeURIComponent) || m.private_instance_methods(false).include?(:unescapeURIComponent) }
abort "still there" if CGI.respond_to?(:unescapeURIComponent)
