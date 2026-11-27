# RAILS_PATH=TREE ruby dump.rb OUT.json: boots a minimal Rails app on the Rails tree at RAILS_PATH (load_defaults 8.1,
# SQLite) and writes every method name an app can collide with: per framework module/class (own methods, by
# visibility), the effective surface of a model, relation, controller, view, job, mailer and core classes, and the
# reserved-name sets Active Record checks (dangerous_attribute_methods, dangerous_class_method?, QUERYING_METHODS).
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  gem "rails", path: ENV.fetch("RAILS_PATH")
  gem "sqlite3"
end
require "json"
require "pp"
require "rake"
require "rails/all"

class App < Rails::Application
  config.load_defaults 8.1
  config.eager_load = true
  config.secret_key_base = "x" * 64
  config.logger = Logger.new(nil)
  config.root = "/tmp/names82-app"
  config.paths["config/database"] = []
  config.action_mailer.delivery_method = :test
  config.active_storage.service = :test
end
ENV["DATABASE_URL"] = "sqlite3::memory:"
require "fileutils"
FileUtils.mkdir_p("/tmp/names82-app/config")
File.write("/tmp/names82-app/config/storage.yml", "test:\n  service: Disk\n  root: /tmp/names82-storage\n")
App.initialize!
Rails.application.eager_load!

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
class Post < ActiveRecord::Base; end
class PostsController < ActionController::Base; end
class ApiController < ActionController::API; end
class AppJob < ActiveJob::Base; end
class AppMailer < ActionMailer::Base; end
class Form; include ActiveModel::Model; include ActiveModel::Attributes; include ActiveModel::Serializers::JSON; include ActiveModel::Dirty; end

def all_instance(mod) = { public: mod.public_instance_methods, protected: mod.protected_instance_methods, private: mod.private_instance_methods }
def all_singleton(obj) = { public: obj.public_methods, protected: obj.protected_methods, private: obj.private_methods }
def minus(a, b) = a.to_h { |vis, names| [vis, (names - b.values.flatten).map(&:to_s).sort] }

plain_class = Class.new
surface = {
  "model.instance" => minus(all_instance(Post), all_instance(Object)),
  "model.class" => minus(all_singleton(Post), all_singleton(plain_class)),
  "relation.instance" => minus(all_instance(Post.all.class), all_instance(Object)),
  "association.instance" => minus(all_instance(ActiveRecord::Associations::CollectionProxy), all_instance(Object)),
  "activemodel.instance" => minus(all_instance(Form), all_instance(Object)),
  "activemodel.class" => minus(all_singleton(Form), all_singleton(plain_class)),
  "controller.instance" => minus(all_instance(PostsController), all_instance(Object)),
  "controller.class" => minus(all_singleton(PostsController), all_singleton(plain_class)),
  "api_controller.instance" => minus(all_instance(ApiController), all_instance(Object)),
  "view.instance" => minus(all_instance(ActionView::Base.with_empty_template_cache), all_instance(Object)),
  "job.instance" => minus(all_instance(AppJob), all_instance(Object)),
  "job.class" => minus(all_singleton(AppJob), all_singleton(plain_class)),
  "mailer.instance" => minus(all_instance(AppMailer), all_instance(Object)),
  "mailer.class" => minus(all_singleton(AppMailer), all_singleton(plain_class)),
}
core = [BasicObject, Object, Kernel, Module, Class, String, Symbol, Array, Hash, Integer, Float, Numeric, BigDecimal,
  Rational, NilClass, TrueClass, FalseClass, Range, Enumerable, Comparable, Time, Date, DateTime, Proc, Method,
  UnboundMethod, Regexp, Exception, Struct, Pathname, IO, File, URI::Generic, Thread, Process::Status, ERB::Util]
core.each do |c|
  surface["core.#{c}.instance"] = all_instance(c).transform_values { |a| a.map(&:to_s).sort }
  surface["core.#{c}.singleton"] = c.is_a?(Module) ? all_singleton(c).transform_values { |a| a.map(&:to_s).sort } : {}
end

prefixes = /\A(ActiveRecord|ActiveModel|ActionController|AbstractController|ActionDispatch|ActionView|ActiveJob|ActionMailer|ActiveSupport|ActiveStorage|ActionCable|ActionText|ActionMailbox|Rails)(::|\z)/
modules = {}
ObjectSpace.each_object(Module) do |m|
  name = (Module.instance_method(:name).bind_call(m) rescue nil)
  next unless name&.match?(prefixes)
  modules[name] = {
    public: m.public_instance_methods(false).map(&:to_s).sort,
    protected: m.protected_instance_methods(false).map(&:to_s).sort,
    private: m.private_instance_methods(false).map(&:to_s).sort,
    singleton: m.singleton_methods(false).map(&:to_s).sort,
    singleton_private: m.singleton_class.private_instance_methods(false).map(&:to_s).sort,
  }
end

candidates = surface.values.flat_map(&:values).flatten.uniq
out = {
  rails: Rails.version, ruby: RUBY_DESCRIPTION, rails_path: ENV["RAILS_PATH"],
  rails_sha: IO.popen(["git", "-C", ENV["RAILS_PATH"], "rev-parse", "HEAD"], &:read).strip,
  reserved: {
    dangerous_attribute_methods: ActiveRecord::AttributeMethods.dangerous_attribute_methods.to_a.sort,
    dangerous_class_methods: candidates.select { |n| Post.send(:dangerous_class_method?, n) }.sort,
    relation_defined: candidates.select { |n| Post.send(:method_defined_within?, n, ActiveRecord::Relation) }.sort,
    restricted_class_methods: ActiveRecord::AttributeMethods::RESTRICTED_CLASS_METHODS,
    querying_methods: ActiveRecord::Querying::QUERYING_METHODS.map(&:to_s).sort,
  },
  surface: surface,
  modules: modules.sort.to_h,
}
File.write(ARGV.fetch(0), JSON.pretty_generate(out))
puts "#{Rails.version} #{out[:rails_sha]}: #{modules.size} modules, #{candidates.size} surface names"
