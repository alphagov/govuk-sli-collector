module GovukSliCollector
  class PublishingLatencySli
    LogEvent = Struct.new(:govuk_request_id, :time)
  end
end
