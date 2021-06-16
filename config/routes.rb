Rails.application.routes.draw do
  post '/webhooks', to: proc { [204, {}, []] }
end
