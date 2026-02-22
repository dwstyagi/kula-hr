class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notifications_user_#{current_user.id}"
  end

  def unsubscribed
  end
end
