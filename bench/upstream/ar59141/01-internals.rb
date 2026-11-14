# Each probe mirrors one gem's use of an Active Record internal that #59141 touched.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.integer :n, default: 3; t.string :type }
end
class Post < ActiveRecord::Base; attribute :virt, :string, default: "v"; end
class Sub < Post; attribute :extra, :integer; end
class Other < ActiveRecord::Base; self.table_name = "posts"; end

def probe(name)
  r = yield
  puts "#{name}: #{r.inspect}"
rescue Exception => e
  puts "#{name}: #{e.class}: #{e.message.lines.first&.strip}"
end

post = Post.create!(title: "a")

# activerecord-import import.rb:1073 (set id after import without RETURNING)
probe("ar-import build_from_database+ivar_set") do
  m = Post.new(title: "x")
  attrs = Post.attributes_builder.build_from_database(m.attributes.merge("id" => 42))
  m.instance_variable_set(:@attributes, attrs)
  [m.id, m.title, m.n, m.virt]
end
# activerecord-import synchronize / import.rb:1010-1025
probe("ar-import write_from_user on fetched set") do
  m = Post.new(title: "x")
  fresh = Post.find(post.id).instance_variable_get(:@attributes)
  attrs = m.instance_variable_get(:@attributes)
  fresh.keys.each { |k| attrs.write_from_user(k, fresh.fetch_value(k)) }
  [m.id, m.title, m.n]
end
probe("ar-import swap @attributes from other record") do
  m = Post.new(title: "x")
  m.instance_variable_set(:@attributes, Post.find(post.id).instance_variable_get(:@attributes))
  [m.id, m.title, m.virt]
end
# counter_culture extensions.rb:229 / counter.rb:386
probe("counter_culture write_from_user on dup") do
  prev = post.dup
  prev.instance_variable_get(:@attributes).write_from_user("n", 99)
  [prev.n, post.n]
end
# attr_encrypted: write_cast_value / write_from_user then read
probe("attr_encrypted write_cast_value") do
  m = Post.new
  m.instance_variable_get(:@attributes).write_cast_value("title", "enc")
  [m.title, m.title_changed?]
end
# globalize: @attributes.reset(name)
probe("globalize @attributes.reset") do
  m = Post.find(post.id); m.title = "z"
  m.instance_variable_get(:@attributes).reset("title")
  [m.title]
end
# mobility query.rb: @attributes.key?(alias)
probe("mobility key? on alias column") do
  m = Post.select("posts.*, 'x' AS __mobility_title_en").first
  a = m.instance_variable_get(:@attributes)
  [a.key?("__mobility_title_en"), a.fetch_value("__mobility_title_en"), m.read_attribute("__mobility_title_en")]
end
# annotaterb / store_model: _default_attributes[name]
probe("_default_attributes[name]") do
  [Post._default_attributes["n"].value_before_type_cast, Post._default_attributes["virt"]&.value, Post._default_attributes["nope"].class]
end
# paranoia: @attributes.frozen?
probe("paranoia @attributes.frozen? after destroy") do
  m = Post.create!(title: "d"); m.destroy
  [m.instance_variable_get(:@attributes).frozen?, m.frozen?]
end
# enumerize / attr_json: becomes + init_with
probe("becomes Other then read") do
  o = post.becomes(Other); [o.title, o.n, o.id, o.class.name]
end
probe("becomes Sub then write+read") do
  s = Post.find(post.id).becomes(Sub); s.extra = 5; s.title = "q"; [s.title, s.extra, s.virt]
end
probe("becomes! save") do
  post2 = Post.create!(title: "b")
  s = post2.becomes!(Sub); s.extra = 5; s.save!; [Post.find(post2.id).class.name]
end
probe("init_with coder hash") do
  coder = {}; Post.find(post.id).encode_with(coder); m = Post.allocate.init_with(coder)
  [m.id, m.title, m.n]
end
probe("YAML round trip") do
  y = YAML.unsafe_load(YAML.dump(Post.find(post.id))); [y.id, y.title, y.virt]
end
probe("Marshal round trip") do
  y = Marshal.load(Marshal.dump(Post.find(post.id))); [y.id, y.title, y.virt]
end
# instantiate with Hash (public-ish, used by many gems)
probe("instantiate hash") { m = Post.instantiate("id" => 9, "title" => "i"); [m.id, m.title, m.n] }
probe("instantiate hash + column_types") do
  m = Post.instantiate({ "id" => 9, "title" => "i", "x" => "5" }, { "x" => ActiveModel::Type::Integer.new }); [m.title, m.read_attribute("x")]
end
probe("instantiate STI hash") { m = Post.instantiate("id" => 9, "type" => "Sub", "extra" => 4); [m.class.name, m.extra] }
probe("_load_from_sql via find_by_sql extra col") { m = Post.find_by_sql("select *, 1+1 as two from posts").first; [m.title, m.two] }
# overriding _read_attribute (globalize, store_model)
probe("override _read_attribute reached by reader") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "posts"; self.inheritance_column = nil; def _read_attribute(n, &b) = n == "title" ? "OVR" : super }
  k.first.title
end
probe("override read_attribute reached by reader") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "posts"; self.inheritance_column = nil; def read_attribute(n, &b) = n == "title" ? "OVR" : super }
  k.first.title
end
# overriding Model#attributes? dup / clone
probe("dup reads") { d = Post.find(post.id).dup; [d.id, d.title, d.virt] }
probe("attributes hash") { Post.find(post.id).attributes }
probe("attribute_names on new") { Post.new.attribute_names }
