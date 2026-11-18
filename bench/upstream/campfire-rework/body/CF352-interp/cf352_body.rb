# #352 body numbers: the presentation filters on four message bodies, booted from each side's Campfire checkout.
# Needs that checkout's test database with fixtures loaded (bin/rails test once). Run with --gems "" (body-numbers.md).
tree = ENV.fetch("UPSTREAM_BENCH_TREE")
Dir.chdir(tree)
ENV["RAILS_ENV"] = "test"
ENV["BUNDLE_GEMFILE"] = File.join(tree, "Gemfile")
require "bundler/setup"
require File.join(tree, "config/environment")

bodies = {
  "plain" => "<div>Plain message with some words</div>",
  "mention + link" => "<div>Hey #{ActionText::Attachment.from_attachable(User.first).to_html} how are you https://basecamp.com/</div>",
  "formatted list" => "<div><strong>bold</strong> and <em>it</em> <ul><li>a</li><li>b</li></ul></div>",
  "Lexxy paragraphs" => "<p>Lexxy paragraph</p><p>another</p>"
}

# Stored and read back like a real message, then rolled back; the mentioned user is a fixture.
contents = {}
ActiveRecord::Base.transaction do
  bodies.each_with_index do |(name, body), i|
    message = Message.create!(room: Room.first, body: body, client_message_id: "bench#{i}", creator: User.first)
    contents[name] = message.reload.body.body
  end
  raise ActiveRecord::Rollback
end

contents.each do |name, content|
  UpstreamBench.report(name) { ContentFilters::TextMessagePresentationFilters.apply(content) }
end
