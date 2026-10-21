# frozen_string_literal: true

# A separate, closed GET-only fixture, NOT BlogProduction's suite fixtures or
# the historical db/seeds.rb snapshot. Preparation uses insert_all! (no model
# callbacks or jobs), like BlogProduction.prepare. Never delete pending work
# from an existing seed to make an async gate pass.
module BlogShowGetOnly
  STAMP = "2026-01-01 00:00:00"
  ARTICLES = [
    {"id" => 1, "title" => "Getting Started with Rails",
      "body" => "Rails is a web application framework running on the Ruby programming language. It makes building web apps faster and easier with conventions over configuration."},
    {"id" => 2, "title" => "Understanding MVC Architecture",
      "body" => "MVC stands for Model-View-Controller. Models handle data and business logic, Views display information to users, and Controllers coordinate between them."},
    {"id" => 3, "title" => "Ruby2JS: Rails Everywhere",
      "body" => "Ruby2JS transpiles Ruby to JavaScript, enabling Rails applications to run in browsers, on Node.js, and at the edge. Same code, different runtimes."}
  ].freeze
  COMMENTS = [
    {"id" => 1, "article_id" => 1, "commenter" => "Alice", "body" => "Great introduction! Rails really does make development faster."},
    {"id" => 2, "article_id" => 1, "commenter" => "Bob", "body" => "I love how Rails handles database migrations automatically."},
    {"id" => 3, "article_id" => 2, "commenter" => "Carol", "body" => "This pattern really helps keep code organized!"}
  ].freeze

  def self.rows(values)
    values.map { _1.merge("created_at" => STAMP, "updated_at" => STAMP) }
  end

  # Explicit disposable fixture preparation only; never a runtime activator.
  def self.prepare
    raise "new disposable storage required" unless Dir["storage/*.sqlite3*"].empty?
    ActiveRecord::Schema.verbose = false
    %w[schema cache_schema queue_schema cable_schema].zip(%w[primary cache queue cable]).each do |schema, connection|
      ActiveRecord::Base.establish_connection(connection.to_sym)
      load "db/#{schema}.rb"
    end
    ActiveRecord::Base.establish_connection(:primary)
    Article.insert_all!(rows(ARTICLES))
    Comment.insert_all!(rows(COMMENTS))
    raise "unexpected preparation jobs" unless SolidQueue::Job.count.zero?
    ActiveRecord::Base.connection_handler.connection_pool_list.each(&:disconnect!)
  end

  # Parent-only read-only validation before spawning cold workers. Does not
  # boot the app, load its schema caches, or force anything in a worker.
  def self.validate(root)
    require "sqlite3"
    primary = SQLite3::Database.new(File.join(root, "production.sqlite3"), readonly: true)
    primary.results_as_hash = true
    raise "GET-only article fixture differs" unless primary.execute("SELECT * FROM articles ORDER BY id") == rows(ARTICLES)
    raise "GET-only comment fixture differs" unless primary.execute("SELECT * FROM comments ORDER BY id") == rows(COMMENTS)
    queue = SQLite3::Database.new(File.join(root, "production_queue.sqlite3"), readonly: true)
    raise "GET-only fixture contains jobs" unless queue.get_first_value("SELECT COUNT(*) FROM solid_queue_jobs").zero?
  ensure
    primary&.close
    queue&.close
  end
end
