class AddCurrencyToPayCharges < ActiveRecord::Migration[5.0]
  def change
    add_column :pay_charges, :currency, :string
  end
end
