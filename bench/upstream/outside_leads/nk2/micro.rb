# Setup for ir.sh: an Action Text-like HTML5 fragment; PATCH (a req/ measurement patch) is loaded when set.
require "nokogiri"
load ENV["PATCH"] if ENV["PATCH"] && !ENV["PATCH"].empty?
HTML = %(<div class="trix-content"><div>Hello <strong>world</strong>, see <a href="https://example.com">this</a></div><action-text-attachment sgid="abc" content-type="image/png"></action-text-attachment><div>more text here</div></div>)
F = Nokogiri::HTML5.fragment(HTML)
