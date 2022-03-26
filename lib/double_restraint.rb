# frozen_string_literal: true

require "restrainer"

class DoubleRestraint
  def initialize(name, timeout:, limit:, long_running_timeout:, long_running_limit:, timeout_errors: [TimeoutError], redis: nil)
    @timeout = timeout
    @long_running_timeout = long_running_timeout
    @timeout_errors = Array(timeout_errors)
    @restrainer = Restrainer.new("DoubleRestrainer(#{name})", limit: limit, redis: redis)
    @long_running_restrainer = Restrainer.new("DoubleRestrainer(#{name}).long_running", limit: long_running_limit, redis: redis)
  end

  def execute
    begin
      @restrainer.throttle do
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
