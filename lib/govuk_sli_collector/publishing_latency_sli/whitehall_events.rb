require "govuk_sli_collector/publishing_latency_sli/log_event"

module GovukSliCollector
  class PublishingLatencySli
    class WhitehallEvents
      def initialize(logit_search:)
        @logit_search = logit_search
      end

      def call(from_time:, to_time:)
        log_event_hashes = logit_search.call(
          app_name: "whitehall-admin",
          route: [
            "admin/edition_workflow#publish",
            "admin/edition_workflow#force_publish",
          ],
          from_time:,
          to_time:,
        )

        log_event_hashes.map do |event_data|
          LogEvent.new(
            govuk_request_id: event_data["govuk_request_id"].first,
            time: started_at_time(event_data),
          )
        end
      end

    private

      attr_reader :logit_search

      def started_at_time(event_data)
        duration_in_milliseconds = event_data["duration"].first.to_i

        timestamp = Time.new(event_data["@timestamp"].first)
        milliseconds_from_timestamp = timestamp.tv_nsec / 1_000_000

        difference_in_seconds =
          (milliseconds_from_timestamp - duration_in_milliseconds) / 1000

        timestamp.floor + difference_in_seconds
      end
    end
  end
end
