# Mastodon census data: local accounts that follow each other and post,
# reply, boost and favourite through Mastodon's own services, with Sidekiq
# workers run inline so home feeds and counters fill as in production.
require "sidekiq/testing"
Sidekiq::Testing.inline!
srand(42)
owner_role = UserRole.find_by!(name: "Owner")
names = %w[alice bob carol dave erin frank grace heidi ivan judy mallory niaj olivia peggy rupert sybil trent victor walter yolanda]
accounts = names.each_with_index.map do |name, i|
  account = Account.create!(username: name, display_name: name.capitalize, note: "Census account #{name} #tag#{i % 4}")
  User.new(email: "#{name}@census.test", password: "census-password-123", password_confirmation: "census-password-123",
    confirmed_at: Time.now.utc, account: account, agreement: true, approved: true, bypass_registration_checks: true,
    role: (i.zero? ? owner_role : nil), locale: "en").tap { _1.save!(validate: false) }.update_columns(approved: true) # skips the MX lookup; registration callbacks reset approved
  account
end
accounts.each_with_index do |account, i|
  accounts.each_with_index { |other, j| FollowService.new.call(account, other) if i != j && (i + j) % 3 != 0 }
end
words = %w[rails ruby postgres census mastodon fediverse coffee garden music books travel code]
statuses = []
240.times do |n|
  account = accounts[n % accounts.size]
  text = "Census post #{n} about #{words.sample} and #{words.sample} ##{words.sample} @#{accounts.sample.username}"
  thread = statuses.sample if n > 40 && n.odd?
  statuses << PostStatusService.new.call(account, text: text, thread: thread, visibility: n % 10 == 3 ? :unlisted : :public)
end
statuses.sample(80).each_with_index { |s, i| FavouriteService.new.call(accounts[(i * 7) % accounts.size], s) rescue nil }
statuses.sample(40).each_with_index { |s, i| ReblogService.new.call(accounts[(i * 5 + 1) % accounts.size], s) rescue nil }
puts({ accounts: Account.count, statuses: Status.count, follows: Follow.count, favourites: Favourite.count }.inspect)
