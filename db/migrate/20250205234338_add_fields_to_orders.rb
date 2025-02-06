class AddFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :latitude, :decimal, precision: 10, scale: 6
    add_column :orders, :longitude, :decimal, precision: 10, scale: 6
  end
end
