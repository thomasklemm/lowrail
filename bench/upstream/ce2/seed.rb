# frozen_string_literal: true

# Data for the CE2 heavier pages (workloads.rb), written by the census
# harness's prepare step after the app's own census data (CENSUS_SET=ce2). Only
# in the censusce2 copies, so the census's own workloads never see it.
# Deterministic: fixed seeds, fixed timestamps, no random IDs in content.
module Ce2Seed
  module_function

  T0 = Time.utc(2026, 11, 1, 12)

  WORDS = %w[cache index query render route session token worker deploy rollback schema column record
    request response header cookie layout partial helper action filter callback queue mailer job].freeze

  def sentence(rng, n) = Array.new(n) { WORDS[rng.rand(WORDS.size)] }.join(" ").capitalize + "."

  # 120 articles with 0-4 comments each (the index pages show 50 and 100), and
  # one 31-column customer for the form page and the save flow.
  def blog
    rng = Random.new(42)
    existing = Article.count
    (existing...120).each do |i|
      at = T0 - (i * 3600)
      article = Article.create!(title: "Release notes #{i + 1}: #{sentence(rng, 3).chomp(".")}",
        body: Array.new(3) { sentence(rng, 12) }.join(" "), created_at: at, updated_at: at)
      rng.rand(0..4).times do |j|
        article.comments.create!(commenter: %w[Alice Bob Carol Dan Erin][(i + j) % 5], body: sentence(rng, 10),
          created_at: at + (j * 60), updated_at: at + (j * 60))
      end
    end
    Customer.create!(account_number: "C-000001", first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
      phone: "+1 555 0100", company: "Analytical Engines Inc.", job_title: "Head of Engineering",
      website: "https://example.com", address_line1: "12 Engine Street", address_line2: "Suite 4",
      city: "Springfield", state: "IL", postal_code: "62701", country: "US", time_zone: "Eastern Time (US & Canada)",
      locale: "en", currency: "USD", status: "active", plan: "business", credit_limit: "5000.00", balance: "1250.50",
      tax_exempt: false, newsletter: true, birthday: Date.new(1985, 12, 10), notes: "Prefers email. Renewal in March.",
      tags: "vip,annual", last_contacted_at: T0, created_at: T0, updated_at: T0)
  end

  # Enough visible stories that the newest page fills 100 (the generator leaves
  # 90), created as FakeDataGenerator does, by its users with its tags.
  def lobsters
    rng = Random.new(42)
    users = User.active.where(is_moderator: false).order(:id).to_a
    tags = Tag.active.order(:id).to_a
    visible = Story.where(is_deleted: false, merged_story_id: nil).count
    (1..[130 - visible, 0].max).each do |i|
      story = Story.create!(user: users[i % users.size], title: "CE2 story #{i}: #{sentence(rng, 4).chomp(".")}",
        url: "https://example.com/ce2/#{i}", description: (sentence(rng, 15) if i.odd?),
        tags: [tags[i % tags.size], tags[(i * 7) % tags.size]].uniq)
      StoryText.create!(id: story.id, title: story.title, description: story.description, body: sentence(rng, 20))
    end
  end

  # 200 more published cards on the Writebook board, so the cards index's
  # geared pages 3 and 4 hold 50 and 100 cards; each with assignees and tags.
  def fizzy
    rng = Random.new(42)
    identity = Identity.find_by!(email_address: "kevin@37signals.com")
    user = identity.users.find_by!(name: "Kevin")
    account = user.account
    Current.set(account: account, user: user) do
      board = account.boards.find_by!(name: "Writebook")
      people = account.users.active.order(:name).to_a
      200.times do |i|
        at = T0 - (i * 3600)
        card = board.cards.create!(title: "CE2 card #{i + 1}: #{sentence(rng, 4).chomp(".")}",
          description: "<p>#{sentence(rng, 14)}</p>", creator: user, status: "published",
          created_at: at, last_active_at: at)
        card.toggle_assignment(people[i % people.size])
        card.toggle_assignment(people[(i + 3) % people.size]) if i.even?
        card.toggle_tag_with(%w[bug feature design copy perf][i % 5])
      end
    end
  end
end
