require "govuk_sli_collector/publishing_latency_sli"

module GovukSliCollector
  def self.call
    PublishingLatencySli.new.call
  end
end
