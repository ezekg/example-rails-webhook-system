class WebhookEvent < ApplicationRecord
  belongs_to :webhook_endpoint, inverse_of: :webhook_events

  validates :event, presence: true
  validates :payload, presence: true

  def deconstruct_keys(keys)
    {
      webhook_endpoint: { url: webhook_endpoint.url },
      event: event,
      payload: payload,
      response: response.symbolize_keys,
    }
  end
end
