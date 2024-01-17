require "govuk_sli_collector/publishing_latency_sli/logit_search"

module GovukSliCollector
  class PublishingLatencySli
    RSpec.describe LogitSearch do
      let(:host) { "https://example.logit.io" }
      let(:basic_auth) { "ABC123" }

      it "makes a request for log data from Logit's OpenSearch API endpoint" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "content-store",
          route: "content_items#update",
          from_time: Time.now,
        )

        expect(logs_request).to have_been_requested
      end

      it "uses HTTP basic auth" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "content-store",
          route: "content_items#update",
          from_time: Time.now,
        )

        expect(
          logs_request.with do |request|
            expect(request.headers).to include("Authorization" => "Basic #{basic_auth}")
          end,
        ).to have_been_requested
      end

      it "requests logs for the given app name" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "thing-publisher",
          route: "content_items#update",
          from_time: Time.now,
        )

        expect(
          logs_request.with do |request|
            expect(filters(request)).to include(
              { "term" => { "kubernetes.labels.app_kubernetes_io/name" => "thing-publisher" } },
            )
          end,
        ).to have_been_requested
      end

      it "requests logs from the app container" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "content-store",
          route: "content_items#update",
          from_time: Time.now,
        )

        expect(
          logs_request.with do |request|
            expect(filters(request)).to include(
              { "term" => { "kubernetes.container.name" => "app" } },
            )
          end,
        ).to have_been_requested
      end

      it "requests logs no older than the given start time" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "content-store",
          route: "content_items#update",
          from_time: Time.new(2023, 11, 16, 12, 15, 0).utc,
        )

        expect(
          logs_request.with do |request|
            expect(filters(request)).to include(
              { "range" => { "@timestamp" => { "gte" => "2023-11-16T12:15:00Z" } } },
            )
          end,
        ).to have_been_requested
      end

      it "optionally requests logs no newer than the given end time" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "content-store",
          route: "content_items#update",
          from_time: Time.new(2023, 11, 16, 12, 15, 0).utc,
          to_time: Time.new(2023, 11, 16, 12, 20, 0).utc,
        )

        expect(
          logs_request.with do |request|
            expect(filters(request)).to include(
              {
                "range" => {
                  "@timestamp" => {
                    "gte" => "2023-11-16T12:15:00Z",
                    "lt" => "2023-11-16T12:20:00Z",
                  },
                },
              },
            )
          end,
        ).to have_been_requested
      end

      it "requests logs matching a given route" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "content-store",
          route: "content_items#update",
          from_time: Time.now,
        )

        expect(
          logs_request.with do |request|
            expect(filters(request)).to include(
              { "term" => { "route" => "content_items#update" } },
            )
          end,
        ).to have_been_requested
      end

      it "requests logs matching multiple given routes" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "publisher-admin",
          route: ["editions#publish", "editions#force_publish"],
          from_time: Time.now,
        )

        expect(
          logs_request.with do |request|
            expect(filters(request)).to include(
              {
                "terms" => {
                  "route" => ["editions#publish", "editions#force_publish"],
                },
              },
            )
          end,
        ).to have_been_requested
      end

      it "optionally requests logs matching multiple given govuk_request_ids" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "content-store",
          route: "content_items#update",
          from_time: Time.now,
          govuk_request_ids: [
            "11-2222222222.333-0.0.0.0-4444",
            "99-8888888888.777-0.0.0.0-6666",
          ],
        )

        expect(
          logs_request.with do |request|
            expect(filters(request)).to include(
              {
                "terms" => {
                  "govuk_request_id" => [
                    "11-2222222222.333-0.0.0.0-4444",
                    "99-8888888888.777-0.0.0.0-6666",
                  ],
                },
              },
            )
          end,
        ).to have_been_requested
      end

      it "requests specific fields to be returned" do
        logs_request = stub_logs_api

        described_class.new(host:, basic_auth:).call(
          app_name: "content-store",
          route: "content_items#update",
          from_time: Time.now,
        )

        expect(
          logs_request.with do |request|
            fields = JSON.parse(request.body).fetch("fields")

            expect(fields).to contain_exactly(
              "duration",
              "govuk_request_id",
              "@timestamp",
            )
          end,
        ).to have_been_requested
      end

      it "parses the json response and returns an array of log event hashes" do
        fixture_path = "spec/fixtures/logit-opensearch-content-store-events.json"
        stub_logs_api(body: JSON.parse(File.read(fixture_path)))

        event_data = described_class.new(host:, basic_auth:).call(
          app_name: "content-store",
          route: "content_items#update",
          from_time: Time.now,
        )

        expect(event_data).to be_an(Array)
        expect(event_data).to all match(
          "@timestamp" => [an_instance_of(String)],
          "govuk_request_id" => [an_instance_of(String)],
        )
      end

      it "wraps and re-raises any HTTP client errors" do
        stub_logs_api(status: 404)

        expect {
          described_class.new(host:, basic_auth:).call(
            app_name: "content-store",
            route: "content_items#update",
            from_time: Time.now,
          )
        }.to raise_error(LogitSearch::Error, /Not Found/)
      end

      it "raises an error if the HTTP response isn't right" do
        stub_logs_api(body: "not JSON")

        expect {
          described_class.new(host:, basic_auth:).call(
            app_name: "content-store",
            route: "content_items#update",
            from_time: Time.now,
          )
        }.to raise_error(LogitSearch::Error, /JSON::ParserError/)

        stub_logs_api(body: [])

        expect {
          described_class.new(host:, basic_auth:).call(
            app_name: "content-store",
            route: "content_items#update",
            from_time: Time.now,
          )
        }.to raise_error(LogitSearch::Error, /no implicit conversion/)

        stub_logs_api(body: { hits: {} })

        expect {
          described_class.new(host:, basic_auth:).call(
            app_name: "content-store",
            route: "content_items#update",
            from_time: Time.now,
          )
        }.to raise_error(LogitSearch::Error, /undefined method `map'/)
      end

      def stub_logs_api(body: { hits: { hits: [] } }, status: 200)
        stub_request(:get, "#{host}/_search")
          .to_return_json(status:, body:)
      end

      def filters(request)
        JSON.parse(request.body).fetch("query").fetch("bool").fetch("filter")
      end
    end
  end
end
