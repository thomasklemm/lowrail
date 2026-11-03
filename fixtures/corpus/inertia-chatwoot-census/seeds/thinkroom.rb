# frozen_string_literal: true

# Thinkroom census data (docs/upstream/inertia-chatwoot-census.md): its
# db/seeds.rb (the demo document and the compound-writing pack), then a
# password account owning 30 documents (five archived, so the index's optional
# archived list has rows), with comments and suggestions on the demo document.
srand(42)
load "db/seeds.rb"

user = User.create!(name: "Census Writer", email: "census@census.test", password: "census-password-123")
demo = Document.find_by!(slug: "demo")
demo.update!(user: user)
29.times do |i|
  doc = Document.create!(user: user, slug: "census-#{i + 1}", title: "Census document #{i + 1}",
    seed_markdown: "# Census document #{i + 1}\n\n" + Array.new(6) { |p| "Paragraph #{p + 1} of document #{i + 1}. " * 6 }.join("\n\n"),
    tags: [%w[draft plan notes][i % 3]])
  doc.update!(archived_at: Time.current - i.hours) if i < 5
end
8.times do |i|
  demo.comments.create!(author_name: %w[Ada Grace Linus Barbara][i % 4], author_kind: i.even? ? "human" : "agent",
    body: "Census comment #{i + 1}: this paragraph could be tighter.", anchor_text: "provenance")
  demo.suggestions.create!(author_name: "Census Agent", author_kind: "agent", body: "Census suggestion #{i + 1}", status: "pending")
end
