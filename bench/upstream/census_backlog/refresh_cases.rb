# frozen_string_literal: true

$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord actionview actionpack activejob activestorage railties].map {
  File.join(ENV.fetch("RAILS_PATH"), _1, "lib")
})
require "active_support"
require "active_support/core_ext/object/try"
require "active_support/callbacks"

class RefreshCallbacks
  include ActiveSupport::Callbacks
  define_callbacks :symbol, :block, :object, :plain
  attr_reader :count

  def initialize
    @count = 0
  end

  def around
    yield
  end

  set_callback :symbol, :around, :around
  set_callback(:block, :around) { |_, inner| inner.call }
  handler = Object.new
  def handler.around(record)
    yield
  end
  set_callback :object, :around, handler

  def run(kind)
    run_callbacks(kind) { @count += 1 }
  end
end

MICRO = {
  "nil_try" => -> { -> { nil.try(:upload) } },
  "nil_try_bang" => -> { -> { nil.try!(:upload) } },
  "nil_kwargs" => -> { -> { nil.try(:upload, 1, mode: :test) {} } },
  "symbol" => -> { r = RefreshCallbacks.new; -> { r.run(:symbol) } },
  "block" => -> { r = RefreshCallbacks.new; -> { r.run(:block) } },
  "object" => -> { r = RefreshCallbacks.new; -> { r.run(:object) } },
  "plain" => -> { r = RefreshCallbacks.new; -> { r.run(:plain) } },
}

if ENV["WORKLOADS"]
  require "active_record"
  require "action_controller"
  require "rack/mock"
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  ActiveRecord::Schema.verbose = false
  ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
  class RefreshPost < ActiveRecord::Base
    self.table_name = "posts"
    around_save :around
    def around
      yield
    end
  end
  class RefreshController < ActionController::Base
    around_action :around
    def around
      yield
    end
    def index
      render plain: "ok"
    end
  end
  MICRO["save"] = -> { r = RefreshPost.create!(title: "a"); -> { r.save! } }
  MICRO["action"] = -> {
    action = RefreshController.action(:index)
    env = Rack::MockRequest.env_for("/")
    -> { status, _, body = action.call(env.dup); raise status.to_s unless status == 200; body.close }
  }

  require "active_storage"
  require "active_storage/attached"
  require "active_storage/attached/model"
  require "tmpdir"
  require "active_storage/service/disk_service"
  require "active_storage/service/registry"
  require "active_storage/reflection"
  require "zeitwerk"
  loader = Zeitwerk::Loader.new
  loader.push_dir(File.join(ENV.fetch("RAILS_PATH"), "activestorage/app/models"))
  loader.setup
  ActiveRecord::Base.include ActiveStorage::Attached::Model
  ActiveRecord::Base.include ActiveStorage::Reflection::ActiveRecordExtensions
  ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)
  ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new("local" => {
    "service" => "Disk", "root" => Dir.tmpdir
  })
  ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch("local")
  ActiveStorage::Blob.record_timestamps = false
  class RefreshAttachedPost < ActiveRecord::Base
    self.table_name = "posts"
    has_many_attached :files
  end
  MICRO["attachment_noop"] = -> {
    r = RefreshAttachedPost.create!(title: "attached")
    -> { r.save! }
  }
  MICRO["attachment_update"] = -> {
    r = RefreshAttachedPost.create!(title: "a")
    -> { r.title = r.title == "a" ? "b" : "a"; r.save! }
  }
end
