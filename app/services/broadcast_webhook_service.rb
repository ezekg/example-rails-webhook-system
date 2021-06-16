class BroadcastWebhookService
  def self.call(event:, payload:)
    new(event: event, payload: payload).call
  end

  def call
    WebhookEndpoint.enabled.find_each do |webhook_endpoint|
      next unless
        webhook_endpoint.subscribed?(event)

      webhook_event = WebhookEvent.create!(
        webhook_endpoint: webhook_endpoint,
        event: event,
        payload: payload,
      )

      WebhookWorker.perform_async(webhook_event.id)
    end
  end

  private

  attr_reader :event, :payload

  def initialize(event:, payload:)
    @event   = event
    @payload = payload
  end
end
