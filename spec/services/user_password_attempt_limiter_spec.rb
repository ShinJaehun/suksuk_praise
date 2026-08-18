require "rails_helper"

RSpec.describe UserPasswordAttemptLimiter, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:email) { "Teacher@Example.com" }
  let(:remote_ip) { "203.0.113.10" }
  let(:limiter) { described_class.new(email: email, remote_ip: remote_ip, cache: cache) }

  it "blocks on the fifth failure for the normalized email and IP" do
    4.times { expect(limiter.record_failure).to eq(false) }

    expect(limiter.record_failure).to eq(true)
    expect(limiter).to be_blocked
    expect(described_class.new(email: " teacher@example.COM ", remote_ip: remote_ip, cache: cache)).to be_blocked
  end

  it "keeps emails and IPs separate" do
    5.times { limiter.record_failure }

    expect(described_class.new(email: "other@example.com", remote_ip: remote_ip, cache: cache)).not_to be_blocked
    expect(described_class.new(email: email, remote_ip: "203.0.113.11", cache: cache)).not_to be_blocked
  end

  it "resets failure and block records" do
    5.times { limiter.record_failure }

    limiter.reset

    expect(limiter).not_to be_blocked
    4.times { expect(limiter.record_failure).to eq(false) }
  end

  it "expires the block ten minutes after the fifth failure" do
    travel_to Time.zone.local(2026, 8, 18, 10, 0, 0) do
      5.times { limiter.record_failure }
      expect(limiter).to be_blocked
    end

    travel_to Time.zone.local(2026, 8, 18, 10, 10, 1) do
      expect(limiter).not_to be_blocked
    end
  end

  it "does not include the raw email or IP in cache keys" do
    expect(limiter.cache_key).not_to include(email)
    expect(limiter.cache_key).not_to include(email.downcase)
    expect(limiter.cache_key).not_to include(remote_ip)
    expect(limiter.block_key).not_to include(email)
    expect(limiter.block_key).not_to include(email.downcase)
    expect(limiter.block_key).not_to include(remote_ip)
  end
end
