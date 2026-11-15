# UA1 differential probe: one line per input with every public result of UserAgent for it, run once against
# useragent main and once against the branch; the two outputs must be byte-identical.
#   ruby -rbundler/setup probe.rb CORPUS > out.txt
# Per user agent: the parsed class and every public reader (each twice, to catch stale memos), every agent's
# product, version and comment, Marshal.dump of the object and its ivars, extend? of every browser class, comparisons, method_missing and respond_to? for
# each product, allow_browser's verdict for :modern and a Hash, and the same readers after mutating the object.
# Versions: Version.new over every version string and odd strings, to_a/to_s/nil?, <=> and == pairs, and to_a
# after mutating the string Version.new was given.
require "action_controller"
require "useragent"

Request = Struct.new(:user_agent)
Blocker = ActionController::AllowBrowser::BrowserBlocker
ADDR = /0x\h+/

def r(obj = nil)
  v = yield
  v.inspect.gsub(ADDR, "0x")
rescue Exception => e
  "!#{e.class}: #{e.message.gsub(ADDR, "0x")}"
end

READERS = %i[class to_s to_str inspect browser version platform os mobile? bot? to_h application build security
             localization webkit real_version trident_version compatibility_view? chromeframe length].freeze

def readers(ua)
  READERS.flat_map do |m|
    [r { ua.respond_to?(m) ? ua.public_send(m) : :no_method }, r { ua.respond_to?(m) ? ua.public_send(m) : :no_method }]
  end + [r { ua.version.to_a }, r { ua.version.nil? }, r { ua.version.to_s }]
end

def agents(ua)
  ua.map do |a|
    r { [a.product, a.version, a.version.to_a, a.version.nil?, a.comment, a.to_s, a.eql?(a), a == a, a.detect_comment { |c| c.include?("o") }] }
  end
end

OTHERS = ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"].freeze

def line(s)
  out = []
  ua = UserAgent.parse(s)
  out.concat(readers(ua))
  out.concat(agents(ua))
  out << r { Marshal.dump(ua) } << r { ua.map { |a| [a.instance_variables, a.version.instance_variables] } }
  base = UserAgent::Browsers::Base.new(ua.to_a)
  out.concat(UserAgent::Browsers.all.map { |k| r { k.extend?(base) } })
  out << r { UserAgent::Browsers.extend(UserAgent::Browsers::Base.new(ua.to_a)).class }
  out.concat(OTHERS.map { |o| p = UserAgent.parse(o); r { [ua <=> p, ua == p, ua < p, ua > p, ua.eql?(p)] } })
  out.concat(%w[120 17.2 1.0 abc].map { |v| r { [ua.version <=> UserAgent::Version.new(v), ua.version == v, ua.version < v] } })
  out.concat(ua.map { |a| r { [ua.respond_to?(a.product), ua.respond_to?(a.product.to_s.upcase), (ua.public_send(a.product.to_s.downcase) rescue $!.class)] } })
  out << r { [ua.respond_to?(:nonexistent_product), ua.respond_to?(:push)] }
  out << r { Blocker.new(Request.new(s), versions: :modern).blocked? }
  out << r { Blocker.new(Request.new(s), versions: { chrome: 130, safari: 18, firefox: 140, edge: 130, opera: 110, ie: false, "wechat browser": 9 }).blocked? }
  # Mutation: readers must follow the object's current state.
  ua.application&.comment&.push("Mobile; somebot")
  out.concat(readers(ua))
  ua << UserAgent.new("Edge", "18.17763")
  out.concat(readers(ua))
  ua.unshift(UserAgent.new("Opera", "9.80", "Windows NT 6.1; U; en"))
  out.concat(readers(ua))
  out.join("\t")
rescue Exception => e
  "!!#{e.class}: #{e.message.gsub(ADDR, "0x")}"
end

ODD = ["", " ", "\t", "\n", "1.0\n", "\n1.0", "abc\n1.2", "1.0 ", " 1.0", "1", "01.002", "1.0.0-beta", "1.0b8", "1a", "a1",
       "1..2", ".1", "1.", "1.2.3.4.5.6.7.8", "99999999999999999999.1", "１２.0", "1.0-rc1", "beta-1", "1_2_3", "v1.2",
       "1.2a3", "4.0b8pre", "1/2", "\u00e9", "1.2 (x)", "1.0\x00".b, "2.0\xff".b].freeze

def version_lines(strings)
  strings.uniq.each_slice(25).map do |group|
    vs = group.map { |s| UserAgent::Version.new(s.dup) rescue nil }
    cells = group.each_with_index.map do |s, i|
      v = vs[i]
      r { [s, v, Marshal.dump(v), v&.to_a, v&.nil?, v&.to_s, v&.to_str, v && (v == nil), v && (v == s), v&.eql?(UserAgent::Version.new(s.dup))] }
    end
    cells.concat(vs.product(vs).map { |a, b| r { a && b && [a <=> b, a == b, a < b] } })
    cells.concat(group.map { |s| r { m = s.dup; v = UserAgent::Version.new(m); m.replace("7.8.9"); [v.to_a, v.to_s, v.nil?, v <=> UserAgent::Version.new("7.8.9")] } })
    cells.join("\t")
  end
end

uas = File.readlines(ARGV[0], chomp: true).map { |s| s.dup.force_encoding(Encoding::UTF_8) }
uas.concat([nil, "", " ", "\t", "Mozilla", "/", "//", "'\"Mozilla/5.0'", "a\nb/1.0 (x)", "Chrome/120\nSafari/1",
            "Mozilla/5.0 (X11; Linux x86_64) \xff\xfe Chrome/120.0".b, "Mozilla/5.0 (X11; Linux x86_64) \xff\xfe Chrome/120.0",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".encode("UTF-16LE"),
            "Mozilla/5.0 (Windows NT 10.0) Chrome/120.0.0.0 Safari/537.36".b, "Mozilla/5.0 (Windows NT 10.0) ÇHRÖME/120.0 Safari/537.36",
            "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0) chromeframe/11.0", "Iron/1.0 Chrome/120 Safari/1",
            "Mozilla/5.0 (Linux) CRIOS/120.0 Safari/1", "Mozilla/5.0,gzip(gfe) Chrome/1", "Mozilla/5.0 (a; b; c; d; e) İ/1.0", "Mozilla/5.0 (X11) Straße/1.0 Chrome/120.0",
            "Foo/1 AppleCoreMedia/1.0.0.12B435 (iPhone; U; CPU OS 8_1_1 like Mac OS X; en_us)"])
uas.each { |s| puts line(s) }
version_strings = ODD + uas.compact.flat_map { |s| (UserAgent.parse(s).map { |a| a.version.to_s } rescue []) }
version_lines(version_strings).each { |l| puts l }
