# Fizzy's NotifyRecipientsJob shape: one record argument, discard_on.
class NotifyRecipientsJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(notifiable)
    notifiable.id
  end
end
