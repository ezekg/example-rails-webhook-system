class AddEnabledToWebhookEndpoints < ActiveRecord::Migration[5.2]
  def change
    add_column :webhook_endpoints, :enabled, :boolean, default: true, index: true
  end
end
