# Usage: ruby openproject_probe.rb [original|no_context]
# A trimmed copy of OpenProject's ModelContract (app/contracts/model_contract.rb @ 9ae6b5cc50)
# on Rails main: the contract shares the model's errors, so it must not clear them.
require "bundler/setup"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:projects) { |t| t.string :name; t.string :identifier } }

class Project < ActiveRecord::Base
  validates :name, presence: true
end

class BaseContract
  include ActiveModel::Validations
  attr_reader :model
  def initialize(model) = @model = model
  def errors = model.errors
end

class ModelContract < BaseContract
  def valid?(context = nil)
    model.valid?(context)
    contract_valid?(context)
  end

  protected

  if ARGV[0] == "original"
    def contract_valid?(context = nil, clear_errors: false)
      current_context = validation_context
      self.validation_context = context
      errors.clear if clear_errors
      run_validations!
    ensure
      self.validation_context = current_context
    end
  else
    def contract_valid?(context = nil, clear_errors: false)
      errors.clear if clear_errors
      run_validations!
    end
  end
end

class Projects::CreateContract < ModelContract
  validate { errors.add(:identifier, :blank) if model.identifier.blank? }
end rescue (module Projects; end; retry)

contract = Projects::CreateContract.new(Project.new)
begin
  p valid: contract.valid?, errors: contract.errors.attribute_names, context_after: contract.validation_context
rescue => e
  puts "#{e.class}: #{e.message.lines.first}"
end
