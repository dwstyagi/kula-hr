class CreatePlatformAdmins < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_admins do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false

      t.timestamps
    end

    add_index :platform_admins, :email, unique: true
  end
end
