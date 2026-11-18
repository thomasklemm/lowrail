load File.join(ENV.fetch("LOWRAIL_ROOT"), "bench/upstream/census10/a1_diff_probe.rb")

$events = []
module ExtraMethods
  def label = "extended"
end
class Post
  after_find { $events << ["find", self.class.name, id] }
  after_initialize { $events << ["initialize", self.class.name, id] }
end
class DefaultPost < ActiveRecord::Base
  self.table_name = "posts"
  default_scope { unscope(where: :user_id).where(published: true) }
end
class User
  has_many :unscope_all_posts, -> { unscope(:where) }, class_name: "Post"
  has_many :or_posts, -> { where(user_id: 0).or(where(published: true)) }, class_name: "Post"
  has_many :merged_posts, -> { merge(Post.unscope(:where).where(user_id: 0)) }, class_name: "Post"
  has_many :none_posts, -> { none }, class_name: "Post"
  has_many :extended_posts, -> { extending(ExtraMethods) }, class_name: "Post"
  has_many :default_posts, class_name: "DefaultPost", foreign_key: :user_id
  has_many :special_posts
  has_many :inverse_posts, class_name: "Post", foreign_key: :user_id, inverse_of: :user
  has_many :strict_posts, class_name: "Post", foreign_key: :user_id, strict_loading: true
  has_many :unscoped_comments, -> { unscope(:where) }, through: :posts, source: :comments
  has_many :nojoin_comments, -> { unscope(where: :post_id) }, through: :posts, source: :comments, disable_joins: true
  has_many :nested_tags, -> { where.not(name: "absent") }, through: :posts, source: :tags
  has_many :retyped_pictures, -> { rewhere(imageable_type: "Other") }, class_name: "Picture", as: :imageable
end

sql = []
ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| sql << p[:sql] unless p[:name] == "SCHEMA" }
record_ids = ->(r) { Array(r).map { |x| [x.class.name, x.attributes] } }
run = lambda do |label, &block|
  sql.clear; WARN.clear; $events.clear
  result = begin
    block.call
  rescue => e
    [e.class.name, e.message.sub(/\(called from .*\z/m, "")]
  end
  puts "EXT #{label}: #{result.inspect}"
  puts " sql #{sql.inspect}"
  puts " warnings #{WARN.inspect}"
  puts " callbacks #{$events.inspect}"
end
names = %i[posts unscope_all_posts or_posts merged_posts none_posts extended_posts default_posts special_posts inverse_posts strict_posts unscoped_comments nojoin_comments nested_tags retyped_pictures]
names.each do |name|
  run.call("load #{name}") { record_ids.call(User.first.public_send(name).to_a) }
  run.call("to_sql #{name}") { User.first.public_send(name).to_sql }
  %i[preload includes eager_load joins left_joins].each do |method|
    run.call("#{method} #{name}") do
      relation = User.where(id: [1, 2]).public_send(method, name).order(:id)
      method.to_s.include?("joins") ? relation.pluck(:id) : relation.map { |u| [u.id, record_ids.call(u.public_send(name).to_a)] }
    end
  end
  run.call("associated #{name}") { User.where.associated(name).order(:id).pluck(:id) }
end
run.call("inverse") { u = User.first; p = u.inverse_posts.first; [p.user.equal?(u), p.user.id] }
run.call("extension") { User.first.extended_posts.label }
run.call("strict owner") { u = User.first; u.strict_loading!; record_ids.call(u.posts.to_a) }
run.call("strict preload") { User.strict_loading.preload(:posts).first.posts.map { |p| [p.id, p.strict_loading?] } }
run.call("strict target") { User.preload(:strict_posts).first.strict_posts.map { |p| [p.id, p.strict_loading?] } }
run.call("create callbacks") { User.first.posts.create!(title: "callback").attributes.slice("title", "user_id") }
