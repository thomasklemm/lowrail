# frozen_string_literal: true

# Hackatime census data (docs/upstream/inertia-chatwoot-census.md). Its
# db/seeds.rb creates the test user, API keys and a week of heartbeats only in
# development and test, so only that check is answered as development while it
# runs (Rails.env and every database configuration stay production). Then 30
# days of coding sessions, heartbeats two minutes apart as editor plugins send
# them, and a few more users for the leaderboard.
srand(42)
Rails.env.define_singleton_method(:development?) { true }
begin
  load "db/seeds.rb"
ensure
  Rails.env.singleton_class.remove_method(:development?)
end

projects = %w[panorama harbor zera tern smokie census]
languages = %w[Ruby TypeScript JavaScript Python Go Markdown]
users = [User.find_by!(slack_uid: "TEST123456")] + Array.new(5) do |i|
  User.create!(slack_uid: "CENSUS#{i}", username: "census#{i}", slack_username: "census#{i}", timezone: "Europe/Tallinn")
end
start = Time.current.beginning_of_day - 30.days
users.each_with_index do |user, u|
  30.times do |day|
    (u.zero? ? 3 : 1).times do |s|
      session_start = start + day.days + (9 + s * 4).hours + rand(0..59).minutes
      project = projects[(day + s + u) % projects.size]
      rand(15..45).times do |beat|
        user.heartbeats.create!(time: (session_start + (beat * 2).minutes).to_f, entity: "src/#{project}/file_#{rand(1..20)}.rb",
          project: project, language: languages[(beat + u) % languages.size], editor: "VS Code", operating_system: "Linux",
          machine: "census-#{u}", category: "coding", source_type: :direct_entry)
      end
    end
  end
end

# The dashboard and projects pages read per-user rollups that a job refreshes
# after heartbeats arrive; build them now, so every run sees the same pages.
users.each { |user| DashboardRollupRefreshJob.perform_now(user.id) }
