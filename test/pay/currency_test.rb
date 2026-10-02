require "test_helper"

class Pay::CurrencyTest < ActiveSupport::TestCase
  {"integers" => 15_39, "strings" => "1539"}.each do |type, amount|
    test "formats amounts from #{type} in different currencies" do
      assert_equal "$15.39", Pay::Currency.format(amount, currency: :usd)
      assert_equal "1 539 Ft", Pay::Currency.format(amount, currency: :huf)
      assert_equal "€15,39", Pay::Currency.format(amount, currency: :eur)
      assert_equal "¥1,539", Pay::Currency.format(amount, currency: :jpy)
      assert_equal "¥15.39", Pay::Currency.format(amount, currency: :cny)
      assert_equal "£15.39", Pay::Currency.format(amount, currency: :gbp)
      assert_equal "1.539 ع.د", Pay::Currency.format(amount, currency: :iqd)
    end
  end

  test "defaults to :usd if currency nil" do
    assert_equal "$15.39", Pay::Currency.format(15_39, currency: nil)
  end

  test "options" do
    assert_equal "$15", Pay::Currency.format(15_39, currency: nil, precision: 0)
  end

  test "additional precision" do
    assert_equal "$0.008", Pay::Currency.format(0.8, currency: nil)
  end

  test "additional precision from string" do
    assert_equal "$0.008", Pay::Currency.format("0.8", currency: nil)
  end
end
