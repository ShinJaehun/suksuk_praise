require "digest"

class UserPasswordAttemptLimiter
  MAX_FAILURES = 5
  WINDOW = 10.minutes
  KEY_PREFIX = "user_password_attempts:v1".freeze

  def initialize(email:, remote_ip:, cache: Rails.cache)
    @email = email.to_s.strip.downcase
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
    "#{KEY_PREFIX}:failures:#{digest}"
  end

  def block_key
    "#{KEY_PREFIX}:blocked:#{digest}"
  end

  private

  attr_reader :email, :remote_ip, :cache

  def digest
    @digest ||= Digest::SHA256.hexdigest([email, remote_ip].join("\0"))
  end
end
