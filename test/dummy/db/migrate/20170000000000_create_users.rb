class CreateUsers < ActiveRecord::Migration[4.2]
  def change
    create_table :users do |t|
      t.string :email, null: false

      t.timestamps
    end
  end
end
