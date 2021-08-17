class AddCurrencyToPayCharges < ActiveRecord::Migration[6.0]
  def change
    add_column :pay_charges, :currency, :string
  end
end
