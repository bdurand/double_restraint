# Double Restraint

[![Continuous Integration](https://github.com/bdurand/double_restraint/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/double_restraint/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

This gem implements a pattern for interacting with external services in a way that prevents performance issues with those services from taking down your application.

Suppose you have a web application that calls a web service for something, and at some point that web service starts to have latency issues and requests take several seconds to return. Eventually most of the processing threads will be be waiting on the web service and your application will be completely unresponsive.

This gem builds atop the [restrainer gem](https://github.com/weheartit/restrainer) which requires a Redis server to coordinate different processes.

With the restrainer gem you can throttle the number of concurrent requests to a service so that, if there is a problem with that service, the damage will be limited to only a set number of processes:

```ruby
restrainer = Restrainer.new("MyWebService", limit: 10)
begin
  restainer.throttle do
    MyWebService.new.call(arguments)
  end
rescue Restrainer::ThrottledError
  puts "Too many concurrent calls to MyWebService"
end
```

This is all well and good, but it can lead to problems if you set too low a limit on the throttled call. You could end up in a situation where peak traffic sends more requests than the limit you set. This will end up artificially limiting the external calls and returning errors to user.

If the external service uses timeouts, then you could also mitigate the issue of locking up your application by setting a low timeout so that requests to the sevice fail fast. However, if some requests to the service just take a little long even in a health system, then you will be artificially preventing these requests from succeeding and creating errors for your users.

This gem combines both solutions and let you set two levels of timeouts and a limit on how many concurrent requests can be using the longer timeout.

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
* The block will be yielded to first with the `timeout` value
* If the first execution of the block raises a timeout error, then it will be called again with the `long_running_timeout` value.
* If there are too many concurrent requests, then a `Restrainer::ThrottledError` will be raised.

The effect of this is that if there are latency issues in `MyWebService`, then the requests will fail fast. Only a handful of requests will be allowed to execute with the higher timeout value. On a healthy system, you shouldn't seen any artificially generated errors as long as your `timeout` is set properly.

You can also set a restraint on the initial execution request by specifying the `limit` parameter.

```ruby
restraint = DoubleRestraint.new("MyWebService", limit: 50, timeout: 0.5, long_running_timeout: 5.0, long_running_limit: 5)
```

You will probably need to specify what constitutes a timeout error as well. Out of the box, only `Timeout::Error` is caught.

```ruby
restraint = DoubleRestraint.new("MyWebService", timeout_errors: [Faraday::TimeoutError], timeout: 0.5, long_running_timeout: 5.0, long_running_limit: 5)
```

Finally, you need to specify the Redis instance to use. By default this uses the value specified for the.

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
$ gem install simple_apm
```

## Contributing

Open a pull request on GitHub.

Please use the [standardrb](https://github.com/testdouble/standard) syntax and lint your code with `standardrb --fix` before submitting.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
