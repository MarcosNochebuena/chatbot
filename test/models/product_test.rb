# == Schema Information
#
# Table name: products
#
#  id          :bigint           not null, primary key
#  description :string
#  key_code    :string
#  name        :string
#  price       :decimal(, )
#  stock       :decimal(, )
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
require "test_helper"

class ProductTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
