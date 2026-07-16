# frozen_string_literal: true

require "timeout"
require "restrainer"

class DoubleRestraint
  attr_reader :timeout, :long_running_timeout

  # @param name [String, Symbol] The name of the restraint.
  # @param timeout [Numeric] The first timeout that will be yielded to the block.
  # @param long_running_timeout [Numeric] The timeout that will be yielded to the block if
  #        the block times out the first time it is executed.
  # @param long_running_limit [Integer] The maximum number of concurrent executions of the block
  #        with the long running timeout across all processes.
  # @param limit [Integer] The maximum number of concurrent executions of the block with the
  #        initial timeout across all processes. If this is nil, then no limit will be applied.
  # @param timeout_errors [Array<Module>] List of errors that will be considered a timeout.
  #        This needs to be customized depending on what the code in the block could throw to
  #        indicate a timeout has occurred.
  # @param redis [Redis] Redis connection to use.
  #        If this is not set, the default value set for `Restrainer.redis` will be used.
  def initialize(name, timeout:, long_running_timeout:, long_running_limit:, limit: nil, timeout_errors: [Timeout::Error], redis: nil)
    @timeout = timeout
    @long_running_timeout = long_running_timeout
    @timeout_errors = Array(timeout_errors)
    limit = -1 if limit.nil?
    # Slots in the underlying restrainers expire as a safeguard against orphaned locks,
    # so the expiration must comfortably exceed the longest time a block can legitimately
    # hold a slot.
    restrainer_timeout = [60, long_running_timeout.to_f * 2].max
    # The restrainer names use "DoubleRestrainer" rather than "DoubleRestraint" for
    # backward compatibility with the Redis keys created by earlier versions of the gem.
    @restrainer = Restrainer.new("DoubleRestrainer(#{name})", limit: limit, timeout: restrainer_timeout, redis: redis)
    @long_running_restrainer = Restrainer.new("DoubleRestrainer(#{name}).long_running", limit: long_running_limit, timeout: restrainer_timeout, redis: redis)
  end

  # Execute a block of code. The block will be yielded with the timeout value. If the block raises
  # a timeout error, then it will be called again with the long running timeout. The code in the block
  # must be idempotent since it can be run twice.
  #
  # @yieldparam [Numeric] the timeout value to use in the block.
  # @return [Object] the value returned by the block.
  # @raise [Restrainer::ThrottledError] if too many concurrent processes are trying to use the restraint.
  def execute
    timed_out = false
    result = @restrainer.throttle do
      yield @timeout
    rescue *@timeout_errors
      # Just flag the timeout here so the retry happens after the throttle
      # block exits and releases its slot in the default pool.
      timed_out = true
      nil
    end

    if timed_out
      result = @long_running_restrainer.throttle do
        yield @long_running_timeout
      end
    end

    result
  end

  # Get the current size of the default pool. This can be useful in
  # collecting realtime stats about how the pool is being utilized.
  #
  # @return [Integer]
  def default_pool_size
    @restrainer.current
  end

  # Get the current size of the long running pool. This can be useful in
  # collecting realtime stats about how the pool is being utilized.
  #
  # @return [Integer]
  def long_running_pool_size
    @long_running_restrainer.current
  end

  # Get the limit for the default pool. This will return -1 if there
  # is no limit set on that pool.
  #
  # @return [Integer]
  def default_pool_limit
    @restrainer.limit
  end

  # Get the limit for the long running pool.
  #
  # @return [Integer]
  def long_running_pool_limit
    @long_running_restrainer.limit
  end

  # Helper method to determine if a timeout represents the long running timeout.
  # Note that the timeout and long running timeouts need to be different values
  # in order for this to work.
  #
  # @return [Boolean]
  def long_running?(timeout)
    timeout.to_f.round(6) == @long_running_timeout.to_f.round(6)
  end
end
