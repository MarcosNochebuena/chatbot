class AddAvailableFieldToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :available, :boolean, default: false
  end
end
