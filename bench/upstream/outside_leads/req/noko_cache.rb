# Measurement patch only: cache the joined CSS->XPath translation per (class contexts, rule, doctype, namespaces).
module Nokogiri::XML::Searchable
  XPATH_FROM_CSS = {}
  def xpath_query_from_css_rule(rule, ns)
    key = [self.class::IMPLIED_XPATH_CONTEXTS, rule.to_s, document.xpath_doctype, ns]
    XPATH_FROM_CSS.fetch(key) do
      XPATH_FROM_CSS[key] = self.class::IMPLIED_XPATH_CONTEXTS.map do |implied_xpath_context|
        visitor = Nokogiri::CSS::XPathVisitor.new(
          builtins: Nokogiri::CSS::XPathVisitor::BuiltinsConfig::OPTIMAL,
          doctype: document.xpath_doctype,
          prefix: implied_xpath_context,
          namespaces: ns,
        )
        Nokogiri::CSS.xpath_for(rule.to_s, visitor: visitor)
      end.join(" | ")
    end
  end
end
