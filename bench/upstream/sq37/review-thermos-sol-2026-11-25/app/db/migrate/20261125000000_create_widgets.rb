class CreateWidgets < ActiveRecord::Migration[8.1]
  def change
    create_table :widgets do |table|
      table.string :name
    end
  end
end
