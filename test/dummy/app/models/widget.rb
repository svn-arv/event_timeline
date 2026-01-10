# frozen_string_literal: true

class Widget
  attr_accessor :name, :price

  def initialize(name:, price:)
    @name = name
    @price = price
  end

  def discounted_price(percent)
    price * (1 - percent / 100.0)
  end
end
