# Measurement patch (UR1): URI's component decoder copies the String once instead of twice.
URI.singleton_class.prepend(Module.new do
  def _decode_uri_component(regexp, str, enc)
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
    str = str.b
    str.gsub!(regexp, URI::TBLDECWWWCOMP_)
    str.force_encoding(enc)
  end
end)
