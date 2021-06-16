class WebhookEndpoint < ApplicationRecord
  has_many :webhook_events, inverse_of: :webhook_endpoint

  validates :subscriptions, length: { minimum: 1 }, presence: true
  validates :url, presence: true

  scope :enabled, -> { where(enabled: true) }

  def subscribed?(event)
    (subscriptions & ['*', event]).any?
  end

  def disable!
    update!(enabled: false)
  end
end
