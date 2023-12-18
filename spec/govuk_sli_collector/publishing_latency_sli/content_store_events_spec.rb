require "govuk_sli_collector/publishing_latency_sli/content_store_events"

module GovukSliCollector
  class PublishingLatencySli
    RSpec.describe ContentStoreEvents do
      let(:logit_opensearch_host) { "https://example.logit.io" }

      let(:logit_search) do
        LogitSearch.new(host: logit_opensearch_host, basic_auth: "ABC123")
      end

      let(:whitehall_events) do
        [
          LogEvent.new(
            govuk_request_id: "11-2222222222.333-0.0.0.0-4444",
            time: Time.now,
          ),
          LogEvent.new(
            govuk_request_id: "99-8888888888.777-0.0.0.0-6666",
            time: Time.now,
          ),
        ]
      end

      it "fetches Content Store logs matching given Whitehall events" do
        body = JSON.parse(File.read("spec/fixtures/logit-opensearch-content-store-events.json"))
        stub_content_store_logs_api(body:)

        from_time = Time.now - 60

        allow(logit_search).to receive(:call).and_call_original

        described_class.new(logit_search:).call(
          matching: whitehall_events,
          from_time:,
        )

        govuk_request_ids = [
          "11-2222222222.333-0.0.0.0-4444",
          "99-8888888888.777-0.0.0.0-6666",
        ]

        expect(logit_search).to have_received(:call).with(
          app_name: "content-store",
          govuk_request_ids:,
          route: "content_items#update",
          from_time:,
        )
      end

      it "returns the events as an array of objects" do
        stub_content_store_logs_api(
          body: {
            hits: {
              hits: [
                "fields" => {
                  "govuk_request_id" => ["11-2222222222.333-0.0.0.0-4444"],
                  "@timestamp" => ["2023-11-16T12:15:40.418Z"],
                },
              ],
            },
          },
        )

        events = described_class.new(logit_search:).call(
          matching: whitehall_events,
          from_time: Time.now + 60,
        )

        expect(events).to contain_exactly(an_instance_of(LogEvent))
        expect(events.first).to have_attributes(
          govuk_request_id: "11-2222222222.333-0.0.0.0-4444",
          time: an_instance_of(Time),
        )
      end

      it "removes subseconds from time, because they're unreliable across apps" do
        stub_content_store_logs_api(
          body: {
            hits: {
              hits: [
                "fields" => {
                  "govuk_request_id" => ["11-2222222222.333-0.0.0.0-4444"],
                  "@timestamp" => ["2023-11-16T12:15:40.418Z"],
                },
              ],
            },
          },
        )

        events = described_class.new(logit_search:).call(
          matching: whitehall_events,
          from_time: Time.now,
        )

        expect(events.first.time).to eq(Time.new(2023, 11, 16, 12, 15, 40))
      end

      def stub_content_store_logs_api(body:)
        stub_request(:get, "#{logit_opensearch_host}/_search")
          .with(body: /content-store/)
          .to_return_json(status: 200, body:)
      end
    end
  end
end
