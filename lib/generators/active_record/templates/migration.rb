# frozen_string_literal: true

class AddPayTo<%= table_name.camelize %> < ActiveRecord::Migration<%= migration_version %>
  def change
    change_table :<%= table_name %> do |t|
<%= migration_data -%>
    end
  end
end
