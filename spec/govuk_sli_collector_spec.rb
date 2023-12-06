require "govuk_sli_collector"

RSpec.describe GovukSliCollector do
  describe "collecting the Publishing Latency SLI" do
    it "invokes PublishingLatencySli#call" do
      publishing_latency_sli = instance_spy(GovukSliCollector::PublishingLatencySli)
      allow(GovukSliCollector::PublishingLatencySli).to receive(:new)
        .and_return(publishing_latency_sli)

      described_class.call

      expect(publishing_latency_sli).to have_received(:call)
    end

    it "sends any exceptions to Sentry and doesn't let them propagate" do
      stub_const("SilencedError", Class.new(StandardError))
      expect(GovukSliCollector::PublishingLatencySli).to receive(:new)
        .and_raise(SilencedError, "This error is sent to Sentry and silenced")

      expect(Error).to receive(:catch_and_report).and_call_original

      expect {
        described_class.call
      }.not_to raise_error
    end
  end
end
