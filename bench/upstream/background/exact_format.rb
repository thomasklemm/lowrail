# RAILS=DIR ruby [--yjit|--zjit] exact_format.rb: AS-1 exactness grid; Representable#format and the variant format for 160 filename x content type pairs (diff main against the branch)
ARGV.replace(["format_png", "0", "stats"])
load File.expand_path("micro.rb", __dir__)
names = ["a.png", "a.PNG", "photo.jpeg", "photo.jpg", "x.gif", "noext", ".gitignore", "a.b.c.png", " sp ace .png ", "a:b/c.png",
  "IMG\u202E.png", "bad\xFF.png".dup.force_encoding("UTF-8"), "bad\xFF.png".b, "ü.jpeg", "a.", "a.tar.gz", "", "a.webp", "a.svg", "a.heic"]
types = %w[image/png image/jpeg image/gif image/webp application/pdf image/svg+xml] + [nil, ""]
out = []
names.product(types).each do |n, t|
  b = ActiveStorage::Blob.new(filename: n, content_type: t)
  r = begin
    v = b.send(:format); [v.inspect, v.class, v.frozen?, (v.encoding rescue nil)].join(" ")
  rescue => e
    "raise #{e.class}: #{e.message}"
  end
  out << "#{n.inspect} #{t.inspect} => #{r}"
  begin
    out << "  variant format #{b.variant(resize_to_limit: [1, 1]).variation.format.inspect}" if ActiveStorage.variable_content_types.include?(t)
  rescue => e
    out << "  variant raise #{e.class}"
  end
end
puts out
