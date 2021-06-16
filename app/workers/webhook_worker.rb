# frozen_string_literal: true

require 'http.rb'

class WebhookWorker
  include Sidekiq::Worker

  sidekiq_options retry: 10, dead: false
  sidekiq_retry_in do |retry_count|
    # Exponential backoff, with a random 30-second to 10-minute "jitter"
    # added in to help spread out any webhook "bursts."
    jitter = rand(30.seconds..10.minutes).to_i

    (retry_count ** 5) + jitter
  end

  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find_by(id: webhook_event_id)
    return if
      webhook_event.nil?

    webhook_endpoint = webhook_event.webhook_endpoint
    return if
      webhook_endpoint.nil?

    return unless
      webhook_endpoint.subscribed?(webhook_event.event) &&
      webhook_endpoint.enabled?

    # Send the webhook request with a 30 second timeout.
    response = HTTP.timeout(30)
                   .headers(
                     'User-Agent' => 'rails_webhook_system/1.0',
                     'Content-Type' => 'application/json',
                   )
                   .post(
                     webhook_endpoint.url,
                     body: {
                       event: webhook_event.event,
                       payload: webhook_event.payload,
                     }.to_json
                   )

    # Store the webhook response.
    webhook_event.update(response: {
      headers: response.headers.to_h,
      code: response.code.to_i,
      body: response.body.to_s,
    })

    # Exit early if the webhook was successful.
    if response.status.success?
      logger.info "[webhook_worker] Delivered webhook event: type=#{webhook_event.event} event=#{webhook_event.id} endpoint=#{webhook_endpoint.id} url=#{webhook_endpoint.url} code=#{response.code}"

      return
    end

    # Handle response errors.
    case webhook_event
    in webhook_endpoint: { url: /\.ngrok\.io/ },
       response: { code: 404, body: /tunnel .+?\.ngrok\.io not found/i }
      logger.warn "[webhook_worker] Deleting dead ngrok endpoint: type=#{webhook_event.event} event=#{webhook_event.id} endpoint=#{webhook_endpoint.id} url=#{webhook_endpoint.url} code=#{response.code}"

      # Automatically delete dead ngrok tunnel endpoints. This error likely
      # means that the developer forgot to remove their temporary ngrok
      # webhook endpoint, seeing as it no longer exists.
      webhook_endpoint.destroy!
    in webhook_endpoint: { url: /\.ngrok\.io/ },
       response: { code: 502 }
      logger.warn "[webhook_worker] Retrying unresponsive ngrok endpoint: type=#{webhook_event.event} event=#{webhook_event.id} endpoint=#{webhook_endpoint.id} url=#{webhook_endpoint.url} code=#{response.code}"

      # The bad gateway error usually means that the tunnel is still open
      # but the local server is no longer responding for any number of
      # reasons. We're going to automatically retry.
      raise FailedRequestError
    in webhook_endpoint: { url: /\.ngrok\.io/ },
       response: { code: 504 }
      logger.warn "[webhook_worker] Disabling bad ngrok endpoint: type=#{webhook_event.event} event=#{webhook_event.id} endpoint=#{webhook_endpoint.id} url=#{webhook_endpoint.url} code=#{response.code}"

      # Automatically disable these since the endpoint is likely an ngrok
      # "stable" URL, but it's not currently running. To save bandwidth,
      # we do not want to automatically retry.
      webhook_endpoint.disable!
    else
      logger.warn "[webhook_worker] Failed webhook event: type=#{webhook_event.event} event=#{webhook_event.id} endpoint=#{webhook_endpoint.id} url=#{webhook_endpoint.url} code=#{response.code}"

      # Raise a failed request error and let Sidekiq handle retrying.
      raise FailedRequestError
    end
  rescue OpenSSL::SSL::SSLError
    logger.warn "[webhook_worker] TLS error for webhook event: type=#{webhook_event.event} event=#{webhook_event.id} endpoint=#{webhook_endpoint.id} url=#{webhook_endpoint.url} code=TLS_ERROR"

    # Since TLS issues may be due to an expired cert, we'll continue retrying
    # since the issue may get resolved within the 3 day retry window. This
    # may be a good place to send an alert to the endpoint owner.
    webhook_event.update(response: { error: 'TLS_ERROR' })

    # Signal the webhook for retry.
    raise FailedRequestError
  rescue HTTP::ConnectionError
    logger.warn "[webhook_worker] Connection error for webhook event: type=#{webhook_event.event} event=#{webhook_event.id} endpoint=#{webhook_endpoint.id} url=#{webhook_endpoint.url} code=CONNECTION_ERROR"

    # This error usually means DNS issues. To save us the bandwidth,
    # we're going to disable the endpoint. This would also be a good
    # location to send an alert to the endpoint owner.
    webhook_event.update(response: { error: 'CONNECTION_ERROR' })

    # Disable the problem endpoint.
    webhook_endpoint.disable!
  rescue HTTP::TimeoutError
    logger.warn "[webhook_worker] Timeout for webhook event: type=#{webhook_event.event} event=#{webhook_event.id} endpoint=#{webhook_endpoint.id} url=#{webhook_endpoint.url} code=TIMEOUT_ERROR"

    # This error means the webhook endpoint timed out. We can either
    # raise a failed request error to trigger a retry, or leave it
    # as-is and consider timeouts terminal. We'll do the latter.
    webhook_event.update(response: { error: 'TIMEOUT_ERROR' })
  end

  private

  def logger
    Sidekiq.logger
  end

  # General failed request error that we're going to use to signal
  # Sidekiq to retry our webhook worker.
  class FailedRequestError < StandardError; end
end
