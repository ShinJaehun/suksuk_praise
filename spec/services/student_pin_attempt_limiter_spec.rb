require "rails_helper"

RSpec.describe StudentPinAttemptLimiter, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  it "blocks after five failures for the same classroom, student, and IP" do
    limiter = described_class.new(classroom_id: 1, student_id: 2, remote_ip: "203.0.113.10", cache: cache)

    4.times { expect(limiter.record_failure).to eq(false) }

    expect(limiter).not_to be_blocked
    expect(limiter.record_failure).to eq(true)
    expect(limiter).to be_blocked
  end

  it "keeps other students, classrooms, and IPs separate" do
    limiter = described_class.new(classroom_id: 1, student_id: 2, remote_ip: "203.0.113.10", cache: cache)
    5.times { limiter.record_failure }

    expect(described_class.new(classroom_id: 1, student_id: 3, remote_ip: "203.0.113.10", cache: cache)).not_to be_blocked
    expect(described_class.new(classroom_id: 2, student_id: 2, remote_ip: "203.0.113.10", cache: cache)).not_to be_blocked
    expect(described_class.new(classroom_id: 1, student_id: 2, remote_ip: "203.0.113.11", cache: cache)).not_to be_blocked
  end

  it "resets failure records after a successful login" do
    limiter = described_class.new(classroom_id: 1, student_id: 2, remote_ip: "203.0.113.10", cache: cache)
    4.times { limiter.record_failure }

    limiter.reset

    4.times { expect(limiter.record_failure).to eq(false) }
  end

  it "blocks for ten minutes from the fifth failure" do
    limiter = described_class.new(classroom_id: 1, student_id: 2, remote_ip: "203.0.113.10", cache: cache)

    travel_to Time.zone.local(2026, 7, 22, 10, 0, 0) do
      4.times { limiter.record_failure }
    end

    travel_to Time.zone.local(2026, 7, 22, 10, 9, 59) do
      expect(limiter.record_failure).to eq(true)
      expect(limiter).to be_blocked
    end

    travel_to Time.zone.local(2026, 7, 22, 10, 10, 1) do
      expect(limiter).to be_blocked
    end

    travel_to Time.zone.local(2026, 7, 22, 10, 19, 58) do
      expect(limiter).to be_blocked
    end

    travel_to Time.zone.local(2026, 7, 22, 10, 20, 0) do
      expect(limiter).not_to be_blocked
    end
  end

  it "removes both failure and block keys on reset" do
    limiter = described_class.new(classroom_id: 1, student_id: 2, remote_ip: "203.0.113.10", cache: cache)
    5.times { limiter.record_failure }

    expect(cache.exist?(limiter.failure_key)).to eq(true)
    expect(cache.exist?(limiter.block_key)).to eq(true)

    limiter.reset

    expect(cache.exist?(limiter.failure_key)).to eq(false)
    expect(cache.exist?(limiter.block_key)).to eq(false)
    expect(limiter).not_to be_blocked
  end

  it "does not include raw PINs or raw tokens in the cache key" do
    limiter = described_class.new(classroom_id: 1, student_id: 2, remote_ip: "203.0.113.10", cache: cache)

    expect(limiter.cache_key).not_to include("1234")
    expect(limiter.cache_key).not_to include("student-login-token")
    expect(limiter.cache_key).not_to include("203.0.113.10")
    expect(limiter.block_key).not_to include("1234")
    expect(limiter.block_key).not_to include("student-login-token")
    expect(limiter.block_key).not_to include("203.0.113.10")
  end
end
