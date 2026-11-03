# Discourse census data: the seed_fu fixtures, then users, categories,
# topics and replies created through PostCreator (Discourse's own write path).
SeedFu.seed(DiscoursePluginRegistry.seed_paths) if Category.count.zero?
srand(42)
SiteSetting.max_new_accounts_per_registration_ip = 0 rescue nil
SiteSetting.min_topic_title_length = 5
SiteSetting.min_post_length = 5
SiteSetting.rate_limit_create_topic = 0
SiteSetting.rate_limit_create_post = 0
SiteSetting.max_topics_per_day = 10_000
SiteSetting.max_replies_in_first_day = 10_000
SiteSetting.unique_posts_mins = 0
RateLimiter.disable
users = 12.times.map do |i|
  User.find_by(username: "census#{i}") || User.create!(username: "census#{i}", name: "Census #{i}", email: "census#{i}@census.test",
    password: "census-password-123", active: true, approved: true, trust_level: 2).tap { _1.activate }
end
users.first.update!(admin: true, moderator: true)
cats = %w[General Rails Postgres Ruby].map do |n|
  Category.find_by(name: n) || Category.create!(name: n, user: Discourse.system_user, color: "0088CC", text_color: "FFFFFF")
end
words = %w[rails ruby postgres census forum discourse coffee garden music books travel code indexes queries]
topics = 60.times.map do |t|
  PostCreator.create!(users[t % users.size], title: "Census topic #{t} about #{words.sample} and #{words.sample}",
    raw: "Opening post #{t}: #{words.sample(8).join(' ')}. @census#{(t + 1) % 12} what do you think?",
    category: cats[t % cats.size].id, skip_validations: true)
end
topics.each_with_index do |op, t|
  (t % 7 + 2).times do |r|
    PostCreator.create!(users[(t + r + 1) % users.size], topic_id: op.topic_id,
      raw: "Reply #{r} to topic #{t}: #{words.sample(10).join(' ')} **bold** and a [link](https://example.com/#{t}/#{r}).",
      skip_validations: true)
  end
end
puts({ users: User.count, topics: Topic.count, posts: Post.count, categories: Category.count }.inspect)
