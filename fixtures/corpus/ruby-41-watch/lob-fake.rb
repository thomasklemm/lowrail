require "rake"
load Rails.root.join("lib/tasks/fake_data.rake").to_s
srand(42)
Faker::Config.random = Random.new(42)
BCrypt::Engine.cost = BCrypt::Engine::MIN_COST
ActiveRecord::Base.transaction(requires_new: false) { FakeDataGenerator.new.generate }
puts [User.count, Story.count, Comment.count, Tag.count].inspect
