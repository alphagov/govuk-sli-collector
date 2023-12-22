require "error"

RSpec.describe Error do
  describe ".catch_and_report" do
    it "sends any exceptions to Sentry and doesn't let them propagate" do
      stub_const("SilencedError", Class.new(StandardError))

      allow(Sentry).to receive(:capture_exception)

      expect {
        described_class.catch_and_report do
          raise SilencedError, "This error is sent to Sentry and silenced"
        end
      }.not_to raise_error

      expect(Sentry).to have_received(:capture_exception)
        .with(an_instance_of(SilencedError))
    end
  end

  describe ".report" do
    it "sends any exceptions to Sentry but also lets them propagate" do
      stub_const("NoisyError", Class.new(StandardError))

      allow(Sentry).to receive(:capture_exception)

      expect {
        described_class.report do
          raise NoisyError, "This error is sent to Sentry and re-raised"
        end
      }.to raise_error(NoisyError)

      expect(Sentry).to have_received(:capture_exception)
        .with(an_instance_of(NoisyError))
    end
  end
end
