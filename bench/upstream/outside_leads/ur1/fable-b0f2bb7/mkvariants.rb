# ruby mkvariants.rb: rebuilds v-* from uri/ (ruby/uri at b0f2bb7), one edit set each.
require "fileutils"
Dir.chdir(__dir__)

HEAD_BLOCK = <<RUBY
  # Only where cgi/escape decodes in C or Java (cgi 0.3.3 and later).
  if CGI.respond_to?(:unescapeURIComponent) && !CGI.method(:unescapeURIComponent).source_location
    # Like URI.decode_www_form_component, except that <tt>'+'</tt> is preserved.
    def self.decode_uri_component(str, enc=Encoding::UTF_8)
      _decode_uri_component(str, enc) {|bytes| CGI.unescapeURIComponent(bytes, Encoding::BINARY) }
    end
  else
    def self.decode_uri_component(str, enc=Encoding::UTF_8) # :nodoc:
      _decode_uri_component(str, enc) {|bytes| bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_) }
    end
  end
RUBY

VARIANTS = {
  # The availability check as ERB writes it for CGI.escapeURIComponent.
  "v-respond" => { "lib/uri/common.rb" => [
    [" && !CGI.method(:unescapeURIComponent).source_location", ""],
  ] },
  # decode_uri_component keeps its gsub on every Ruby: no availability check.
  "v-gsub" => { "lib/uri/common.rb" => [
    [HEAD_BLOCK, <<RUBY],
  # Like URI.decode_www_form_component, except that <tt>'+'</tt> is preserved.
  def self.decode_uri_component(str, enc=Encoding::UTF_8)
    _decode_uri_component(str, enc) {|bytes| bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_) }
  end
RUBY
  ] },
  # The suggested polish: same behaviour as head.
  "v-polish" => {
    "lib/uri/common.rb" => [
      ["{|bytes| CGI.unescape(bytes, Encoding::BINARY) }", "{|bytes| CGI.unescape(bytes, Encoding::ASCII_8BIT) }"],
      [HEAD_BLOCK, <<RUBY],
  if CGI.respond_to?(:unescapeURIComponent) && !CGI.method(:unescapeURIComponent).source_location
    # Like URI.decode_www_form_component, except that <tt>'+'</tt> is preserved.
    def self.decode_uri_component(str, enc=Encoding::UTF_8)
      _decode_uri_component(str, enc) {|bytes| CGI.unescapeURIComponent(bytes, Encoding::ASCII_8BIT) }
    end
  else # cgi before 0.3.3, or a CGI.unescapeURIComponent written in Ruby
    def self.decode_uri_component(str, enc=Encoding::UTF_8)
      _decode_uri_component(str, enc) {|bytes| bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_) }
    end
  end
RUBY
      [<<RUBY, <<RUBY2],
  # Returns a string decoded by the block from the bytes of the given
  # \\URL-encoded string +str+.
RUBY
  # Returns the given \\URL-encoded string +str+ decoded in encoding +enc+;
  # the block decodes its bytes.
RUBY2
    ],
    "test/uri/test_common.rb" => [
      [<<RUBY, ""],
    assert_equal("\\x82\\x33\\xE7\\x34 ".force_encoding("UTF-8"),
                 URI.decode_www_form_component("\\x82\\x33\\xE7\\x34+".force_encoding("GB18030")))
RUBY
      [<<RUBY, ""],
    assert_equal("\\x82\\x33\\xE7\\x34+".force_encoding("UTF-8"),
                 URI.decode_uri_component("\\x82\\x33\\xE7\\x34+".force_encoding("GB18030")))
RUBY
      ["    assert_equal(String, URI.decode_www_form_component(Class.new(String).new(\"a\")).class)\n",
       "    assert_instance_of(String, URI.decode_www_form_component(Class.new(String).new(\"a\")))\n"],
      ["    assert_equal(String, URI.decode_uri_component(Class.new(String).new(\"a\")).class)\n",
       "    assert_instance_of(String, URI.decode_uri_component(Class.new(String).new(\"a\")))\n"],
      ["    assert_raise(ArgumentError){URI.decode_www_form_component(\"%zz\")}\n", ""],
      ["    assert_raise(ArgumentError){URI.decode_uri_component(\"%zz\")}\n", ""],
    ],
  },
}

VARIANTS.each do |dir, files|
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(dir)
  FileUtils.cp_r(%w[uri/lib uri/test], dir)
  files.each do |file, edits|
    path = File.join(dir, file)
    code = File.read(path)
    edits.each do |from, to|
      code.include?(from) or abort "#{dir}: not found:\n#{from}"
      code = code.sub(from) { to }
    end
    File.write(path, code)
  end
  puts "built #{dir}"
end

# v-native: one availability check gates both decoders; elsewhere both keep master's gsub.
# Built from v-polish (same test changes), lib rewritten by line ranges of the head file.
dir = "v-native"
FileUtils.rm_rf(dir); FileUtils.mkdir_p(dir)
FileUtils.cp_r(%w[v-polish/lib v-polish/test], dir)
path = "#{dir}/lib/uri/common.rb"
code = File.read("uri/lib/uri/common.rb")
doc = code[/^  # Returns a string decoded from the given \\URL-encoded string \+str\+\.\n(?:  #.*\n)+?(?=  def self\.decode_www_form_component)/] or abort "doc"
www = doc + <<RUBY
  def self.decode_www_form_component(str, enc=Encoding::UTF_8)
    _decode_uri_component(str, enc) {|bytes| CGI.unescape(bytes, Encoding::BINARY) }
  end

RUBY
code.include?(www) or abort "www"
code.include?(HEAD_BLOCK + "\n") or abort "block"
code = code.sub(HEAD_BLOCK + "\n", "")
indent = ->(s) { s.gsub(/^(?=.)/, "  ") }
code = code.sub(www) { <<RUBY }
  if CGI.respond_to?(:unescapeURIComponent) && !CGI.method(:unescapeURIComponent).source_location
#{indent.(doc).chomp}
    def self.decode_www_form_component(str, enc=Encoding::UTF_8)
      _decode_uri_component(str, enc) {|bytes| CGI.unescape(bytes, Encoding::ASCII_8BIT) }
    end

    # Like URI.decode_www_form_component, except that <tt>'+'</tt> is preserved.
    def self.decode_uri_component(str, enc=Encoding::UTF_8)
      _decode_uri_component(str, enc) {|bytes| CGI.unescapeURIComponent(bytes, Encoding::ASCII_8BIT) }
    end
  else # cgi before 0.3.3, or cgi/escape written in Ruby
    def self.decode_www_form_component(str, enc=Encoding::UTF_8)
      _decode_uri_component(str, enc) {|bytes| bytes.gsub(/\\+|%\\h\\h/, TBLDECWWWCOMP_) }
    end

    def self.decode_uri_component(str, enc=Encoding::UTF_8)
      _decode_uri_component(str, enc) {|bytes| bytes.gsub(/%\\h\\h/, TBLDECWWWCOMP_) }
    end
  end

RUBY
code = code.sub(<<RUBY, <<RUBY2)
  # Returns a string decoded by the block from the bytes of the given
  # \\URL-encoded string +str+.
RUBY
  # Returns the given \\URL-encoded string +str+ decoded in encoding +enc+;
  # the block decodes its bytes.
RUBY2
File.write(path, code)
puts "built #{dir}"
