class AddLastEditedAtToAnnouncements < ActiveRecord::Migration[8.1]
  def change
    add_column :announcements, :last_edited_at, :datetime
  end
end
