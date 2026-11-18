# Filters four message bodies (plain, mention + link, formatted list, Lexxy paragraphs) 2,000 times, best of 5.
# usage: RAILS_ENV=test bin/rails runner cf352_filters.rb, in a Campfire checkout with fixtures loaded
require "benchmark"
ActiveRecord::Base.transaction do
  bodies = [
    "<div>Plain message with some words</div>",
    "<div>Hey #{ActionText::Attachment.from_attachable(User.first).to_html} how are you https://basecamp.com/</div>",
    "<div><strong>bold</strong> and <em>it</em> <ul><li>a</li><li>b</li></ul></div>",
    "<p>Lexxy paragraph</p><p>another</p>",
  ]
  messages = bodies.map.with_index { |b, i| Message.create!(room: Room.first, body: b, client_message_id: "b#{i}", creator: User.first) }
  contents = messages.map { |m| m.reload.body.body }
  3.times { contents.each { |c| ContentFilters::TextMessagePresentationFilters.apply(c) } }
  n = 2000
  best = 5.times.map { Benchmark.realtime { n.times { contents.each { |c| ContentFilters::TextMessagePresentationFilters.apply(c) } } } }.min
  puts "#{ENV['LABEL']}: #{(best / (n * contents.size) * 1e6).round(1)} µs/message"
  raise ActiveRecord::Rollback
end
