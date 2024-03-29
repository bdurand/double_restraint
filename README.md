# Double Restraint

[![Continuous Integration](https://github.com/bdurand/double_restraint/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/double_restraint/actions/workflows/continuous_integration.yml)
[![Regression Test](https://github.com/bdurand/double_restraint/actions/workflows/regression_test.yml/badge.svg)](https://github.com/bdurand/double_restraint/actions/workflows/regression_test.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/double_restraint.svg)](https://badge.fury.io/rb/double_restraint)

This gem implements a pattern for interacting with external services in a way that prevents performance issues with those services from taking down your application. It builds atop the [restrainer gem](https://github.com/bdurand/restrainer) which requires a Redis server to coordinate processes.

## Usage

Suppose you have a web application that calls a web service for something, and at some point that web service starts to have latency issues and requests take several seconds to return. Eventually most your application threads will be be waiting on the web service and your application will be completely unresponsive.

If the external service uses timeouts, you could mitigate the issue of locking up your application by setting a low timeout so that requests to the sevice fail fast. However, if some requests to the service take just a little longer even in a health system, then you will be artificially preventing these requests from succeeding.

With the [restrainer gem](https://github.com/bdurand/restrainer) you can throttle the number of concurrent requests to a service so that, if there is a problem with that service, only a limited number of application threads would be affected:

```ruby
restrainer = Restrainer.new("MyWebService", limit: 10)
begin
  restrainer.throttle do
    MyWebService.new.call(arguments)
  end
rescue Restrainer::ThrottledError
  puts "Too many concurrent calls to MyWebService"
end
```

However, this can lead to problems if you set the limit too low. You could end up in a situation where peak traffic sends more requests than the limit you set. This will end up artificially limiting the external calls and returning errors to users.

This gem combines both solutions and lets you set two levels of timeouts and a limit on how many concurrent requests can use the longer timeout. You can be more aggressive with both your fail fast timeout and the limit on concurrent processes without affecting requests in a health system.

```ruby
restraint = DoubleRestraint.new("MyWebService", timeout: 0.5, long_running_timeout: 5.0, long_running_limit: 5)
begin
  restraint.execute do |timeout|
    MyWebService.new(timeout: timeout).call(arguments)
  end
rescue Restrainer::ThrottledError
  puts "Too many concurrent calls to MyWebService"
end
```

* The `timeout` value should be set to a low value that works for most requests in a healthy system.
* The `long_running_timeout` value should be set to a higher value that works for all requests in a health system.
* The `long_running_limit` value is the maximum number of concurrent requests that are allowed using the higher timeout.

The `execute` call will call the block with the `timeout` value. If the block raises a timeout error, then it will be called again with the `long_running_timeout` value inside a `Restrainer`. If there are too many concurrent requests, then a `Restrainer::ThrottledError` will be raised.

The effect of this is that if there are latency issues in `MyWebService`, then the requests will fail fast. Only a handful of requests will be allowed to execute with the higher timeout value so the impact on the overall system will be very limited. On a healthy system, you shouldn't seen any artificially generated errors as long as your `timeout` is set properly.

The `execute` block **must** be idempotent since it can be run twice by one call to `execute`.

You can also set a restraint on the initial execution with the lower timeout by specifying the `limit` parameter.

```ruby
restraint = DoubleRestraint.new("MyWebService", limit: 50, timeout: 0.5, long_running_timeout: 5.0, long_running_limit: 5)
```

By default, a timeout is identified by any error that inherits from `Timeout::Error`. You may need to specify what constitutes a timeout error in your block of code, though. For instance, if you code uses Faraday to make an HTTP requests, then you would need to specify that timeouts are identified by `Faraday::TimeoutError`.

```ruby
restraint = DoubleRestraint.new("MyWebService", timeout_errors: [Faraday::TimeoutError], timeout: 0.5, long_running_timeout: 5.0, long_running_limit: 5)
```

Finally, you need to specify the Redis instance to use. By default this uses the value specified for the [restrainer gem](https://github.com/bdurand/restrainer).

```ruby
# set the global Redis instance
Restrainer.redis = Redis.new(url: redis_url)

# or use a block to specify a value that is yielded at runtime
Restrainer.redis{ connection_pool.redis }
```

However, you can also specify the Redis instance directly on the `DoubleRestraint` instance.

```ruby
restraint = DoubleRestraint.new("MyWebService", redis: Redis.new(url: redis_url)), timeout: 0.5, long_running_timeout: 5.0, long_running_limit: 5)
```

You can peek at the current pool sizes as well if you want:

```ruby
# Number of process currently using a slot in the default pool
restraint.default_pool_size

# Number of process currently using a slot in the long running pool
restraint.long_running_pool_size

# Get the percentage capacity being used as a whole
total_pool_used = restraint.pool_size + restraint.long_running_pool_size
total_pool_capacity = restraint.limit + restraint.long_running_limit
total_pool_used.to_f / total_pool_capacity
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem "double_restraint"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install double_restraint
```

## Contributing

Open a pull request on GitHub.

Please use the [standardrb](https://github.com/testdouble/standard) syntax and lint your code with `standardrb --fix` before submitting.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
