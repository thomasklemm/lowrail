# frozen_string_literal: true

# Chatwoot census data (docs/upstream/inertia-chatwoot-census.md), loaded by the
# harness's prepare step after db/seeds.rb. One account seeded by Chatwoot's
# own Seeders::AccountSeeder (the super-admin "seed account" feature: teams,
# agents, labels, canned responses, inboxes, contacts, conversations and
# messages from lib/seeders/seed_data.yml), plus an administrator who signs in.
require "faker" # Chatwoot's Gemfile lists it outside the production group's requires
srand(42)
Faker::Config.random = Random.new(42)

# db/seeds.rb's production branch starts the installation onboarding flow,
# which redirects the dashboard; this installation is already set up.
Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)

account = Account.create!(name: "Census Inc")
admin = User.new(name: "Census Admin", email: "census-admin@census.test", password: "Census-password-1!", type: "SuperAdmin")
admin.skip_confirmation!
admin.save!
AccountUser.create!(account: account, user: admin, role: :administrator)

ENV["ENABLE_ACCOUNT_SEEDING"] = "true"
Seeders::AccountSeeder.new(account: account).perform!

# The administrator joins every inbox, as an agent who answers them would.
account.inboxes.find_each { |inbox| InboxMember.find_or_create_by!(user: admin, inbox: inbox) }

# The seeded conversations hold one to three messages each; give the web
# widget's first conversation a longer thread, as a support chat has.
conversation = account.conversations.joins(:inbox).where(inboxes: { channel_type: "Channel::WebWidget" }).order(:id).first!
conversation.update!(assignee: admin)
30.times do |i|
  incoming = i.even?
  conversation.messages.create!(account: account, inbox: conversation.inbox, message_type: incoming ? :incoming : :outgoing,
    sender: incoming ? conversation.contact : admin, content: incoming ? Faker::Lorem.paragraph(sentence_count: 2) : Faker::Lorem.sentence)
end
