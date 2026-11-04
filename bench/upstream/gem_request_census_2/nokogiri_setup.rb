# frozen_string_literal: true

# Setup for gem_request_census/ir_region.sh and cpu_ns.rb: DocumentFragment#css on an Action Text-like HTML5 fragment
# and on a Loofah fragment (docs/upstream/gem-request-census-2.md). Put nokogiri's lib (with its compiled extension),
# loofah's and crass's lib directories on the load path with -I.
#   RUBYFLAGS="-I NOKOGIRI/lib -I LOOFAH/lib -I CRASS/lib" bash ../gem_request_census/ir_region.sh \
#     $PWD/nokogiri_setup.rb 'NOKO.css("action-text-attachment")' 2000 500
require "nokogiri"
require "loofah"
HTML = <<~HTML.freeze
  <div class="trix-content"><p>Hello <strong>world</strong>, see <a href="https://example.com">this</a>.</p>
  <ul><li>one</li><li>two</li></ul><action-text-attachment sgid="abc" content-type="image/png"></action-text-attachment>
  <p>Last paragraph</p></div>
HTML
NOKO = Nokogiri::HTML5.fragment(HTML)
LOOFAH = Loofah.html5_fragment(HTML)
DOC = Nokogiri::HTML5(HTML)
