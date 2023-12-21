require "govuk_sli_collector/publishing_latency_sli/log_event"

module GovukSliCollector
  class PublishingLatencySli
    class ContentStoreEvents
      def initialize(logit_search:)
        @logit_search = logit_search
      end

      def call(matching:, from_time:)
        govuk_request_ids = matching.map(&:govuk_request_id)

        log_event_hashes = logit_search.call(
          app_name: "content-store",
          govuk_request_ids:,
          route: "content_items#update",
          from_time:,
        )

        log_event_hashes.map do |event_data|
          LogEvent.new(
            govuk_request_id: event_data["govuk_request_id"].first,
            time: Time.new(event_data["@timestamp"].first).floor,
          )
        end
      end

    private

      attr_reader :logit_search
    end
  end
end
