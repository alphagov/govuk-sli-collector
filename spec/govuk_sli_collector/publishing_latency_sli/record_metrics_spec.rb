require "govuk_sli_collector/publishing_latency_sli/record_metrics"

module GovukSliCollector
  class PublishingLatencySli
    RSpec.describe RecordMetrics do
      let(:prometheus_registry) { Prometheus::Client.registry }

      let(:first_content_metric) { instance_spy(Prometheus::Client::Histogram) }
      let(:all_content_metric) { instance_spy(Prometheus::Client::Histogram) }

      before do
        allow(prometheus_registry).to receive(:histogram)
          .with(:publishing_latency_first_content_s, any_args)
          .and_return(first_content_metric)

        allow(prometheus_registry).to receive(:histogram)
          .with(:publishing_latency_all_content_s, any_args)
          .and_return(all_content_metric)
      end

      it "derives metrics for Prometheus from the log data" do
        whitehall_events = [
          LogEvent.new(
            govuk_request_id: "11-2222222222.333-0.0.0.0-4444",
            time: Time.new(2023, 11, 16, 12, 15, 56),
          ),
          LogEvent.new(
            govuk_request_id: "99-8888888888.777-0.0.0.0-6666",
            time: Time.new(2023, 11, 16, 12, 15, 53),
          ),
        ]

        content_store_events = [
          LogEvent.new(
            govuk_request_id: "11-2222222222.333-0.0.0.0-4444",
            time: Time.new(2023, 11, 16, 12, 16, 1), # i.e. finished in 5s
          ),
          LogEvent.new(
            govuk_request_id: "99-8888888888.777-0.0.0.0-6666",
            time: Time.new(2023, 11, 16, 12, 16, 2), # i.e. finished in 9s
          ),
          LogEvent.new(
            govuk_request_id: "99-8888888888.777-0.0.0.0-6666",
            time: Time.new(2023, 11, 16, 12, 16, 0), # i.e. finished in 7s
          ),
          LogEvent.new(
            govuk_request_id: "99-8888888888.777-0.0.0.0-6666",
            time: Time.new(2023, 11, 16, 12, 15, 55), # i.e. finished in 2s
          ),
        ]

        described_class.new(prometheus_registry:)
          .call(whitehall_events:, content_store_events:)

        expect(first_content_metric).to have_received(:observe).with(5)
        expect(all_content_metric).to have_received(:observe).with(5)

        expect(first_content_metric).to have_received(:observe).with(2)
        expect(all_content_metric).to have_received(:observe).with(9)
      end

      it "throws away negative latencies that are due to timestamp inaccuracies" do
        whitehall_events = [
          LogEvent.new(
            govuk_request_id: "11-2222222222.333-0.0.0.0-4444",
            time: Time.new(2023, 11, 16, 12, 15, 56),
          ),
        ]

        content_store_events = [
          LogEvent.new(
            govuk_request_id: "11-2222222222.333-0.0.0.0-4444",
            time: Time.new(2023, 11, 16, 12, 15, 55), # i.e. finished in -1s
          ),
        ]

        described_class.new(prometheus_registry:)
          .call(whitehall_events:, content_store_events:)

        expect(first_content_metric).not_to have_received(:observe)
        expect(all_content_metric).not_to have_received(:observe)
      end
    end
  end
end
