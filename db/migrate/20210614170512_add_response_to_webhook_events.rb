class AddResponseToWebhookEvents < ActiveRecord::Migration[5.2]
  def change
    add_column :webhook_events, :response, :jsonb, default: {}
  end
end
