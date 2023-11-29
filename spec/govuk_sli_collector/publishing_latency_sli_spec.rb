require "govuk_sli_collector/publishing_latency_sli"

module GovukSliCollector
  RSpec.describe PublishingLatencySli do
    let(:logit_opensearch_host) { "https://example.logit.io" }
    let(:pushgateway) { instance_spy(Prometheus::Client::Push) }

    before do
      allow(Prometheus::Client::Push).to receive(:new).and_return(pushgateway)
    end

    after do
      Prometheus::Client.registry.metrics.each do |metric|
        Prometheus::Client.registry.unregister(metric.name)
      end
    end

    it "requires some environment variables to run" do
      expect {
        described_class.new
      }.to raise_error(KeyError)
    end

    it "derives metrics from log data and pushes them to Prometheus" do
      stub_whitehall_logs_api
      stub_content_store_logs_api

      ClimateControl.modify(
        INTERVAL_MINUTES: "5",
        OFFSET_MINUTES: "5",
        LOGIT_OPENSEARCH_BASIC_AUTH: "ABC123",
        LOGIT_OPENSEARCH_HOST: logit_opensearch_host,
        PROMETHEUS_PUSHGATEWAY_URL: "http://prometheus-pushgateway.local",
      ) do
        described_class.new.call
      end

      expect(pushgateway).to have_received(:add)
        .with(Prometheus::Client.registry)
    end

    it "exits early if there were no Whitehall logs data" do
      stub_whitehall_logs_api(body: { hits: { hits: [] } })

      allow(PublishingLatencySli::ContentStoreEvents).to receive(:new)
        .and_call_original

      ClimateControl.modify(
        INTERVAL_MINUTES: "5",
        OFFSET_MINUTES: "5",
        LOGIT_OPENSEARCH_BASIC_AUTH: "ABC123",
        LOGIT_OPENSEARCH_HOST: logit_opensearch_host,
        PROMETHEUS_PUSHGATEWAY_URL: "http://prometheus-pushgateway.local",
      ) do
        described_class.new.call
      end

      expect(PublishingLatencySli::ContentStoreEvents).not_to have_received(:new)
    end

    it "exits early if there were no Content Store logs data" do
      stub_whitehall_logs_api
      stub_content_store_logs_api(body: { hits: { hits: [] } })

      allow(PublishingLatencySli::RecordMetrics).to receive(:new)
        .and_call_original

      ClimateControl.modify(
        INTERVAL_MINUTES: "5",
        OFFSET_MINUTES: "5",
        LOGIT_OPENSEARCH_BASIC_AUTH: "ABC123",
        LOGIT_OPENSEARCH_HOST: logit_opensearch_host,
        PROMETHEUS_PUSHGATEWAY_URL: "http://prometheus-pushgateway.local",
      ) do
        described_class.new.call
      end

      expect(PublishingLatencySli::RecordMetrics).not_to have_received(:new)
    end

    it "gets Whitehall logs from within a given time interval, upto an offset" do
      whitehall_events = instance_spy(PublishingLatencySli::WhitehallEvents)
      allow(whitehall_events).to receive(:call).and_return([])
      allow(PublishingLatencySli::WhitehallEvents).to receive(:new)
        .and_return(whitehall_events)

      time_now = Time.new(2023, 11, 16, 12, 15, 30)
      ten_minutes_ago = Time.new(2023, 11, 16, 12, 5, 30)
      thirty_minutes_ago = Time.new(2023, 11, 16, 11, 45, 30)

      ClimateControl.modify(
        INTERVAL_MINUTES: "20",
        OFFSET_MINUTES: "10",
        LOGIT_OPENSEARCH_BASIC_AUTH: "ABC123",
        LOGIT_OPENSEARCH_HOST: logit_opensearch_host,
        PROMETHEUS_PUSHGATEWAY_URL: "http://prometheus-pushgateway.local",
      ) do
        Timecop.freeze(time_now) do
          described_class.new.call
        end
      end

      expect(whitehall_events).to have_received(:call).with(
        from_time: thirty_minutes_ago,
        to_time: ten_minutes_ago,
      )
    end

    it "gets Content Store logs from the beginning of the time interval" do
      stub_whitehall_logs_api

      content_store_events = instance_spy(
        PublishingLatencySli::ContentStoreEvents,
      )
      allow(content_store_events).to receive(:call).and_return([])
      allow(PublishingLatencySli::ContentStoreEvents).to receive(:new)
        .and_return(content_store_events)

      time_now = Time.new(2023, 11, 16, 12, 15, 30)
      thirty_minutes_ago = Time.new(2023, 11, 16, 11, 45, 30)

      ClimateControl.modify(
        INTERVAL_MINUTES: "20",
        OFFSET_MINUTES: "10",
        LOGIT_OPENSEARCH_BASIC_AUTH: "ABC123",
        LOGIT_OPENSEARCH_HOST: logit_opensearch_host,
        PROMETHEUS_PUSHGATEWAY_URL: "http://prometheus-pushgateway.local",
      ) do
        Timecop.freeze(time_now) do
          described_class.new.call
        end
      end

      expect(content_store_events).to have_received(:call).with(
        matching: anything,
        from_time: thirty_minutes_ago,
      )
    end

    def whitehall_fixture
      fixture_path = "spec/fixtures/logit-opensearch-whitehall-events.json"
      JSON.parse(File.read(fixture_path))
    end

    def stub_whitehall_logs_api(body: whitehall_fixture)
      stub_request(:get, "#{logit_opensearch_host}/_search")
        .with(body: /whitehall-admin/)
        .to_return_json(status: 200, body:)
    end

    def content_store_fixture
      fixture_path = "spec/fixtures/logit-opensearch-content-store-events.json"
      JSON.parse(File.read(fixture_path))
    end

    def stub_content_store_logs_api(body: content_store_fixture)
      stub_request(:get, "#{logit_opensearch_host}/_search")
        .with(body: /content-store/)
        .to_return_json(status: 200, body:)
    end
  end
end
