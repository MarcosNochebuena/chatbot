class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.string :phone
      t.string :name
      t.date :delivery_date
      t.time :delivery_time
      t.text :items
      t.text :address
      t.string :location
      t.decimal :total
      t.integer :status

      t.timestamps
    end
  end
end
