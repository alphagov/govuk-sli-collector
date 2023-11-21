require "govuk_sli_collector/publishing_latency_sli/whitehall_events"

module GovukSliCollector
  class PublishingLatencySli
    RSpec.describe WhitehallEvents do
      let(:logit_opensearch_host) { "https://example.logit.io" }

      let(:logit_search) do
        LogitSearch.new(host: logit_opensearch_host, basic_auth: "ABC123")
      end

      it "fetches publish events from Whitehall's logs" do
        body = JSON.parse(File.read("spec/fixtures/logit-opensearch-whitehall-events.json"))
        stub_whitehall_logs_api(body:)

        from_time = Time.now - 60
        to_time = Time.now

        allow(logit_search).to receive(:call).and_call_original

        described_class.new(logit_search:).call(from_time:, to_time:)

        expect(logit_search).to have_received(:call).with(
          app_name: "whitehall-admin",
          route: [
            "admin/edition_workflow#publish",
            "admin/edition_workflow#force_publish",
          ],
          from_time:,
          to_time:,
        )
      end

      it "returns the events as an array of objects" do
        stub_whitehall_logs_api(
          body: {
            hits: {
              hits: [
                "fields" => {
                  "@timestamp" => ["2023-11-16T12:15:39.418Z"],
                  "duration" => [12.86],
                  "govuk_request_id" => ["11-2222222222.333-0.0.0.0-4444"],
                },
              ],
            },
          },
        )

        events = described_class.new(logit_search:)
          .call(from_time: Time.now, to_time: Time.now)

        expect(events).to contain_exactly(an_instance_of(LogEvent))
        expect(events.first).to have_attributes(
          time: an_instance_of(Time),
          govuk_request_id: "11-2222222222.333-0.0.0.0-4444",
        )
      end

      it "removes subseconds from time, because they're unreliable across apps" do
        stub_whitehall_logs_api(
          body: {
            hits: {
              hits: [
                "fields" => {
                  "duration" => [100.0],
                  "govuk_request_id" => ["11-2222222222.333-0.0.0.0-4444"],
                  "@timestamp" => ["2023-11-16T12:15:40.418Z"],
                },
              ],
            },
          },
        )

        events = described_class.new(logit_search:).call(
          from_time: Time.now,
          to_time: Time.now,
        )

        expect(events.first.time).to eq(Time.new(2023, 11, 16, 12, 15, 40))
      end

      it "uses event's #time to record when it started (timestamp - duration)" do
        stub_whitehall_logs_api(
          body: {
            hits: {
              hits: [
                "fields" => {
                  "@timestamp" => ["2023-11-16T12:15:39.418Z"],
                  "duration" => [1000.86],
                  "govuk_request_id" => ["11-2222222222.333-0.0.0.0-4444"],
                },
              ],
            },
          },
        )

        events = described_class.new(logit_search:)
          .call(from_time: Time.now, to_time: Time.now)

        expect(events.first.time).to eq(Time.new(2023, 11, 16, 12, 15, 38))
      end

      def stub_whitehall_logs_api(body:)
        stub_request(:get, "#{logit_opensearch_host}/_search")
          .with(body: /whitehall-admin/)
          .to_return_json(status: 200, body:)
      end
    end
  end
end
