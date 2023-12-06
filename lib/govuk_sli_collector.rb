require "error"
require "govuk_sli_collector/publishing_latency_sli"

module GovukSliCollector
  def self.call
    Error.catch_and_report { PublishingLatencySli.new.call }
  end
end
