# frozen_string_literal: true

# The 8.1 counterpart of sql_log_layers.rb, for script/upstream-bench on 8-1-stable: one find_by logged at debug,
# with AR::LogSubscriber#sql switched off (message formatting, bind rendering and the logger write gone; the
# Notifications dispatch to the log subscriber stays), and at info.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.integer :author_id; t.timestamps }
end
class Post < ActiveRecord::Base; end
Post.create!(title: "Hello", author_id: 1)

log = File.open(File::NULL, "w")
DEBUG = ActiveSupport::Logger.new(log, level: :debug)
INFO = ActiveSupport::Logger.new(log, level: :info)

$off = nil
$state = :unset
ActiveRecord::LogSubscriber.prepend(Module.new { def sql(event) = $off == :format ? nil : super })

{ "full" => nil, "no_format" => :format, "info" => :info }.each do |name, off|
  UpstreamBench.report(name) do
    if $state != off
      $state = $off = off
      ActiveRecord::Base.logger = off == :info ? INFO : DEBUG
    end
    Post.find_by(id: 1)
  end
end
