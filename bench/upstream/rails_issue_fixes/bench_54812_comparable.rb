require "rails"
require "active_record/railtie"
require "active_storage/engine"
require "action_text/engine"
ENV["DATABASE_URL"] = "sqlite3::memory:"
class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "secret_key_base"
  config.active_storage.service = :local
  config.active_storage.service_configurations = { local: { root: Dir.tmpdir, service: "Disk" } }
end
Rails.application.initialize!
ActiveRecord::Migration.verbose = false
require ActiveStorage::Engine.root.join("db/migrate/20170806125915_create_active_storage_tables.rb").to_s
ActiveRecord::Schema.define do
  CreateActiveStorageTables.new.change
  create_table(:posts, force: true) { |t| t.datetime :some_timestamp }
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"; t.string "name", null: false; t.bigint "record_id", null: false; t.string "record_type", null: false; t.timestamps
  end
end
class Post < ActiveRecord::Base; has_rich_text :body; end
class Post < ActiveRecord::Base; has_rich_text :body; end
html = "<div>" + (1..20).map { |i| "<p>Paragraph #{i} with <strong>bold</strong> and <a href=\"/x/#{i}\">a link</a> text text text.</p>" }.join + "</div>"
post = Post.create!(body: html)
post = Post.find(post.id); post.body
rt = post.body
p [:size, rt.body_before_type_cast.bytesize, :changed, rt.body_changed?]
def rt_(&b) t=Process.clock_gettime(Process::CLOCK_MONOTONIC); b.call; Process.clock_gettime(Process::CLOCK_MONOTONIC)-t end
n = 2000
rt.body_changed?
t = rt_ { n.times { rt.body_changed? } }
puts "body_changed? #{(t / n * 1e6).round(1)} us"
t = rt_ { 200.times { post.touch } }
puts "post.touch #{(t / 200 * 1e6).round(1)} us"
