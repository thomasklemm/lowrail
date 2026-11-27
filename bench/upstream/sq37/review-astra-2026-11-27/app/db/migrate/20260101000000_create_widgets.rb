class CreateWidgets < ActiveRecord::Migration[8.2]
  def change
    create_table(:widgets) { |t| t.string :name }
  end
end
