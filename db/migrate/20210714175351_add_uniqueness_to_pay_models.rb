class AddUniquenessToPayModels < ActiveRecord::Migration[5.2]
  def change
    add_index :pay_charges, [:processor, :processor_id], unique: true
    add_index :pay_subscriptions, [:processor, :processor_id], unique: true
  end
end
