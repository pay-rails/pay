class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :email
      t.string :first_name
      t.string :last_name
    end

    create_table :teams do |t|
      t.string :email
      t.string :name
      t.references :owner, polymorphic: true
    end
  end
end
