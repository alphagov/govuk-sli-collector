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
  end
end
