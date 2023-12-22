require "sentry-ruby"

class Error
  class << self
    def catch_and_report(&block)
      configure

      block.call
    rescue StandardError => e
      Sentry.capture_exception(e)
    end

    def report(&block)
      configure

      block.call
    rescue StandardError => e
      Sentry.capture_exception(e)

      raise e
    end

  private

    def configure
      @configure ||= begin
        Sentry.init
        true
      end
    end
  end
end
