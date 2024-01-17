require "json"
require "rest-client"

module GovukSliCollector
  class PublishingLatencySli
    class LogitSearch
      class Error < StandardError; end

      def initialize(host:, basic_auth:)
        @url = URI.join(host, "_search").to_s
        @basic_auth = basic_auth
      end

      def call(app_name:, route:, from_time:, to_time: nil, govuk_request_ids: [])
        response = RestClient::Request.execute(
          method: :get,
          url:,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Basic #{basic_auth}",
          },
          payload: {
            query: {
              bool: {
                filter: [
                  { term: { "kubernetes.labels.app_kubernetes_io/name": app_name } },
                  { term: { "kubernetes.container.name": "app" } },
                  (
                    if route.is_a?(Array)
                      { terms: { route: } }
                    else
                      { term: { route: } }
                    end
                  ),
                  {
                    range: {
                      "@timestamp": {
                        gte: from_time.iso8601,
                        lt: (to_time.iso8601 unless to_time.nil?),
                      }.compact,
                    },
                  },
                  (
                    unless govuk_request_ids.empty?
                      { terms: { govuk_request_id: govuk_request_ids } }
                    end
                  ),
                ].compact,
              },
            },
            fields: ["duration", "govuk_request_id", "@timestamp"],
            _source: false,
          }.to_json,
        )

        payload = JSON.parse(response.body)
        payload["hits"]["hits"].map { |event_data| event_data["fields"] }
      rescue StandardError => e
        raise Error, e.inspect
      end

    private

      attr_reader :url, :basic_auth
    end
  end
end
