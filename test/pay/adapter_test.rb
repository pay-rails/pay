require "test_helper"

class Pay::AdapterTest < ActiveSupport::TestCase
  test "current_adapter returns adapter as string" do
    assert_includes %w[postgresql mysql2 sqlite3], Pay::Adapter.current_adapter
  end

  test "jsonb for postgres" do
    Pay::Adapter.stubs(:current_adapter).returns("postgresql")
    assert_equal :jsonb, Pay::Adapter.json_column_type
  end

  test "json for other databases" do
    Pay::Adapter.stubs(:current_adapter).returns("mysql2")
    assert_equal :json, Pay::Adapter.json_column_type

    Pay::Adapter.stubs(:current_adapter).returns("sqlite3")
    assert_equal :json, Pay::Adapter.json_column_type
  end
end
