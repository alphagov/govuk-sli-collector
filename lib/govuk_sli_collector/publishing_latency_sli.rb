require "prometheus/client"
require "prometheus/client/push"

require "govuk_sli_collector/publishing_latency_sli/content_store_events"
require "govuk_sli_collector/publishing_latency_sli/logit_search"
require "govuk_sli_collector/publishing_latency_sli/record_metrics"
require "govuk_sli_collector/publishing_latency_sli/whitehall_events"

module GovukSliCollector
  class PublishingLatencySli
    def initialize
      @logit_search = LogitSearch.new(
        host: ENV.fetch("LOGIT_OPENSEARCH_HOST"),
        basic_auth: ENV.fetch("LOGIT_OPENSEARCH_BASIC_AUTH"),
      )
      @prometheus_pushgateway_url = ENV.fetch("PROMETHEUS_PUSHGATEWAY_URL")
      @to_time = minutes_ago(Integer(ENV.fetch("OFFSET_MINUTES")))
      @from_time = @to_time - minutes(Integer(ENV.fetch("INTERVAL_MINUTES")))
    end

    def call
      whitehall_events = WhitehallEvents.new(logit_search:).call(
        from_time:,
        to_time:,
      )

      return if whitehall_events.empty?

      content_store_events = ContentStoreEvents.new(logit_search:).call(
        from_time:,
        matching: whitehall_events,
      )

      return if content_store_events.empty?

      prometheus_registry = Prometheus::Client.registry

      RecordMetrics.new(prometheus_registry:).call(
        whitehall_events:,
        content_store_events:,
      )

      Prometheus::Client::Push.new(
        job: "govuk_sli_collector_publishing_latency_sli",
        gateway: prometheus_pushgateway_url,
      ).add(prometheus_registry)
    end

  private

    attr_reader :logit_search,
                :prometheus_pushgateway_url,
                :from_time,
                :to_time

    def minutes(number_of)
      number_of * 60
    end

    def minutes_ago(number_of)
      Time.now.utc - minutes(number_of)
    end
  end
end
