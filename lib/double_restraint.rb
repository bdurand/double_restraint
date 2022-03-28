# frozen_string_literal: true

require "restrainer"

class DoubleRestraint
  # @param name [String, Symbol] The name of the restraint.
  # @param timeout [Numeric] The first timeout that will be yielded to the block.
  # @param long_running_timeout [Numeric] The timeout that will be yielded to the block if
  #        the block times out the first time it is excuted.
  # @param long_running_limit [Integer] The maximum number of times the block can be run
  #        with the long running timeout across all processes.
  # @param limit [Integer] The maximum of number of times the block can be run with the initial
  #        timeout across all processes.
  # @param timeout_errors [Array<Module>] List of errors that will be considered a timeout.
  #        This needs to be customized depending on what the code in the block could throw to
  #        indicate a timeout has occurred.
  # @param redis [Redis] Redis connection to use.
  #        If this is not set, the default value set for `Restrainer.redis` will be used.
  def initialize(name, timeout:, long_running_timeout:, long_running_limit:, limit: nil, timeout_errors: [Timeout::Error], redis: nil)
    @timeout = timeout
    @long_running_timeout = long_running_timeout
    @timeout_errors = Array(timeout_errors)
    @restrainer = Restrainer.new("DoubleRestrainer(#{name})", limit: limit, redis: redis) if limit
    @long_running_restrainer = Restrainer.new("DoubleRestrainer(#{name}).long_running", limit: long_running_limit, redis: redis)
  end

  # Execute a block of code. The block will be yielded with the timeout value. If the block raises
  # a timeout error, then it will be called again with the long running timeout. The code in the block
  # must be idempotent since it can be run twice.
  # @yieldparam [Numeric] the timeout value to use in the block.
  # @raise [Restrainer::ThrottleError] if too many concurrent processes are trying to use the restraint.
  def execute
    begin
      if @restrainer
        @restrainer.throttle do
          yield @timeout
        end
      else
        yield @timeout
      end
    rescue => e
      if @timeout_errors.any? { |error_class| e.is_a?(error_class) }
        @long_running_restrainer.throttle do
          yield @long_running_timeout
        end
      else
        raise e
      end
    end
  end
end
