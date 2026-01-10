# frozen_string_literal: true

class CalculatorService
  def self.add(a, b)
    a + b
  end

  def self.multiply(a, b)
    a * b
  end

  def self.process(values)
    values.map { |v| v * 2 }
  end
end
