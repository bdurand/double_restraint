# Double Restraint

[![Continuous Integration](https://github.com/bdurand/double_restraint/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/double_restraint/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

This gem implements a pattern for interacting with external services in a way that prevents performance issues with those services from taking down your application.

For instance, suppose you have a web application that calls a web service for something. At some point that web service starts to have latency issues and requests take several seconds to return. Now requests to your application will start to back up and eventually all of your application thread might be waiting on the web service and your application is then completely down.

With this gem, you can define limits on how many requests to the web service are allowed to be made at once. Further more, you also specify a fast fail timeout and a long running timeout.

[restrainer gem](https://github.com/weheartit/restrainer)

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
