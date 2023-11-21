require "prometheus/client"

module GovukSliCollector
  class PublishingLatencySli
    class RecordMetrics
      def initialize(prometheus_registry:)
        @prometheus_registry = prometheus_registry
      end

      def call(whitehall_events:, content_store_events:)
        return [] if whitehall_events.empty? || content_store_events.empty?

        first_content = prometheus_registry.histogram(
          :publishing_latency_first_content_s,
          docstring: "Publishing latency for a single content item, in seconds",
        )
        all_content = prometheus_registry.histogram(
          :publishing_latency_all_content_s,
          docstring: "Publishing latency for all affected content items, in seconds",
        )

        content_store_events_by_id = content_store_events.group_by(&:govuk_request_id)

        whitehall_events.each do |whitehall_event|
          matching_events = content_store_events_by_id[whitehall_event.govuk_request_id]

          next if matching_events.nil? || matching_events.empty?

          first_content_store_time, last_content_store_time = matching_events.map(&:time).minmax

          (first_content_store_time - whitehall_event.time).tap do |latency|
            first_content.observe(latency) unless latency.negative?
          end
          (last_content_store_time - whitehall_event.time).tap do |latency|
            all_content.observe(latency) unless latency.negative?
          end
        end
      end

    private

      attr_reader :prometheus_registry
    end
  end
end
