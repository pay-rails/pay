require "test_helper"

class Pay::Adapter::Test < ActiveSupport::TestCase
  test "current_adapter returns adapter as string" do
    assert_includes %w(postgresql mysql2 sqlite3), Pay::Adapter.current_adapter
  end

  test "jsonb for postgres" do
    Pay::Adapter.stub(:current_adapter, "postgresql") do
      assert_equal :jsonb, Pay::Adapter.json_column_type
    end
  end

  test "json for other databases" do
    Pay::Adapter.stub(:current_adapter, "mysql2") do
      assert_equal :json, Pay::Adapter.json_column_type
    end

    Pay::Adapter.stub(:current_adapter, "sqlite3") do
      assert_equal :json, Pay::Adapter.json_column_type
    end
  end
end
