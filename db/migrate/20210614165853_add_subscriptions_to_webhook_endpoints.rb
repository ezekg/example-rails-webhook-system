class AddSubscriptionsToWebhookEndpoints < ActiveRecord::Migration[5.2]
  def change
    add_column :webhook_endpoints, :subscriptions, :jsonb, default: ['*']
  end
end
