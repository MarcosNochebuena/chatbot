# == Schema Information
#
# Table name: products
#
#  id          :bigint           not null, primary key
#  available   :boolean          default(FALSE)
#  description :string
#  key_code    :string
#  name        :string
#  price       :decimal(, )
#  stock       :decimal(, )
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Product < ApplicationRecord
end
