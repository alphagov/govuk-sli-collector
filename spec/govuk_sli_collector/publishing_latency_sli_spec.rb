require "govuk_sli_collector/publishing_latency_sli"

module GovukSliCollector
  RSpec.describe PublishingLatencySli do
    it "requires no arguments to run" do
      expect {
        described_class.new.call
      }.not_to raise_error
    end
  end
end
