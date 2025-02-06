# == Schema Information
#
# Table name: orders
#
#  id            :bigint           not null, primary key
#  address       :text
#  delivery_date :date
#  delivery_time :time
#  items         :text
#  latitude      :decimal(10, 6)
#  location      :string
#  longitude     :decimal(10, 6)
#  name          :string
#  phone         :string
#  status        :integer
#  total         :decimal(, )
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require "test_helper"

class OrderTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
