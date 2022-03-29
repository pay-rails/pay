require "test_helper"

class Pay::Currency::Test < ActiveSupport::TestCase
  test "formats amounts in different currencies" do
    assert_equal "$15.39", Pay::Currency.format(15_39, currency: :usd)
    assert_equal "1 539 Ft", Pay::Currency.format(15_39, currency: :huf)
    assert_equal "€15,39", Pay::Currency.format(15_39, currency: :eur)
    assert_equal "¥1,539", Pay::Currency.format(15_39, currency: :jpy)
    assert_equal "¥15.39", Pay::Currency.format(15_39, currency: :cny)
    assert_equal "£15.39", Pay::Currency.format(15_39, currency: :gbp)
    assert_equal "1.539 ع.د", Pay::Currency.format(15_39, currency: :iqd)
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
end
