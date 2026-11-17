# Lobsters' own seeds, then its fake data generator with fixed seeds, under the
# app's own queue adapter (as the registered census prepares it).
load "db/seeds.rb"
Rails.application.load_tasks # defines FakeDataGenerator
BCrypt::Engine.cost = BCrypt::Engine::MIN_COST
srand(42)
Faker::Config.random = Random.new(42)
measured = ActiveJob::Base.queue_adapter
ActiveJob::Base.queue_adapter = Rails.application.config.active_job.queue_adapter
begin
  ActiveRecord::Base.transaction(requires_new: false) { FakeDataGenerator.new.generate }
ensure
  ActiveJob::Base.queue_adapter = measured
end
