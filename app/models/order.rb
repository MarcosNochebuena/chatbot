# == Schema Information
#
# Table name: orders
#
#  id            :bigint           not null, primary key
#  address       :text
#  delivery_date :date
#  delivery_time :time
#  items         :text
#  location      :string
#  name          :string
#  phone         :string
#  status        :integer
#  total         :decimal(, )
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class Order < ApplicationRecord
  # enum status: { pending: 0, confirmed: 1, delivered: 2, canceled: 3 }, _prefix: true
end
