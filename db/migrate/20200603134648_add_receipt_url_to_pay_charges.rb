class AddReceiptUrlToPayCharges < ActiveRecord::Migration[4.2]
  def change
    add_column :pay_charges, :receipt_url, :string
  end
end
