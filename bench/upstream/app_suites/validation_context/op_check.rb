require "bundler/setup"
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:projects) { |t| t.string :name; t.string :identifier } }
class Project < ActiveRecord::Base
  validates :name, presence: true
  validates :identifier, presence: true, on: :saving_custom_fields
end
MODE = ARGV[0]
class ModelContract
  include ActiveModel::Validations
  attr_reader :model
  def initialize(m) = @model = m
  def errors = model.errors
  def valid?(context = nil)
    model.valid?(context)
    contract_valid?(context)
  end
  def contract_valid?(context = nil, clear_errors: false)
    case MODE
    when "original"
      begin
        cur = validation_context; self.validation_context = context
        run_validations!
      ensure
        self.validation_context = cur
      end
    when "no_context" then run_validations!
    when "public_api"
      prior = errors.dup
      ActiveModel::Validations.instance_method(:valid?).bind_call(self, context)
      errors.merge!(prior)
      errors.empty?
    end
  end
end
class ProjectContract < ModelContract
  SEEN = []
  validate { SEEN << validation_context; errors.add(:base, "contract") if model.name == "bad" }
  validate(on: :saving_custom_fields) { errors.add(:base, "on-context contract rule") }
  def valid?(context = :saving_custom_fields) = super
end
c = ProjectContract.new(Project.new(name: "bad"))
r = begin; c.valid?; rescue => e; "#{e.class}"; end
puts "#{MODE.ljust(10)} AR #{ActiveRecord::VERSION::STRING} valid=#{r} errors=#{c.errors.full_messages.inspect} contract_saw_context=#{ProjectContract::SEEN.inspect}"
