require "digest"

class StudentPinAttemptLimiter
  MAX_FAILURES = 5
  WINDOW = 10.minutes
  KEY_PREFIX = "student_pin_attempts:v1".freeze

  def initialize(classroom_id:, student_id:, remote_ip:, cache: Rails.cache)
    @classroom_id = classroom_id
    @student_id = student_id
    @remote_ip = remote_ip.to_s
    @cache = cache
  end

  def blocked?
    cache.exist?(block_key)
  end

  def record_failure
    count = cache.increment(failure_key, 1, expires_in: WINDOW)
    unless count
      cache.write(failure_key, 1, expires_in: WINDOW)
      count = 1
    end

    if count >= MAX_FAILURES
      cache.write(block_key, true, expires_in: WINDOW)
      true
    else
      false
    end
  end

  def reset
    cache.delete(failure_key)
    cache.delete(block_key)
  end

  def cache_key
    failure_key
  end

  def failure_key
    digest = Digest::SHA256.hexdigest([classroom_id, student_id, remote_ip].join(":"))
    "#{KEY_PREFIX}:failures:#{digest}"
  end

  def block_key
    digest = Digest::SHA256.hexdigest([classroom_id, student_id, remote_ip].join(":"))
    "#{KEY_PREFIX}:blocked:#{digest}"
  end

  private

  attr_reader :classroom_id, :student_id, :remote_ip, :cache
end
