require "nokogiri"
HTML = %(<div class="trix-content"><div>Hello <strong>world</strong>, see <a href="https://example.com">this</a></div><action-text-attachment sgid="abc" content-type="image/png"></action-text-attachment><div>more text here</div></div>)
F = Nokogiri::HTML5.fragment(HTML)
XP = F.send(:xpath_query_from_css_rule, "action-text-attachment", F.document.root ? F.document.root.namespaces : {}) rescue nil
V = Nokogiri::CSS::XPathVisitor.new(builtins: Nokogiri::CSS::XPathVisitor::BuiltinsConfig::OPTIMAL, doctype: F.document.xpath_doctype, prefix: ".//", namespaces: {})
K = Nokogiri::CSS::SelectorCache.key(selector: "action-text-attachment", visitor: V)
K2 = ["action-text-attachment", :optimal, :html5, ".//", {}]
H2 = { K2 => 1 }
K3 = ["action-text-attachment", :optimal, :html5, ".//", nil]
H3 = { K3 => 1 }
