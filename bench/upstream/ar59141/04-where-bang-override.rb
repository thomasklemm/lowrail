# mobility 1.3.2 (plugins/active_record/query.rb) extends the relation returned by Model.i18n with a module that
# overrides where! to rewrite translated attributes; where, find_by and find used to go through it.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :name } }
class Post < ActiveRecord::Base
  QueryExtension = Module.new do
    def where!(opts, *rest) = opts.is_a?(Hash) && opts.key?(:title) ? super({ name: opts[:title] }, *rest) : super
  end
  def self.i18n = all.extending(QueryExtension)
end
Post.create!(name: "foo")
%w[where find_by].each do |m|
  print "Post.i18n.#{m}(title: 'foo'): "
  r = Post.i18n.public_send(m, title: "foo")
  puts(r.respond_to?(:to_a) ? r.to_a.map(&:name).inspect : r&.name.inspect)
rescue => e
  puts "#{e.class}: #{e.message.lines.first.strip}"
end
