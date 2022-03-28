Gem::Specification.new do |spec|
  spec.name = "double_restraint"
  spec.version = File.read(File.expand_path("VERSION", __dir__)).strip
  spec.authors = ["Brian Durand"]
  spec.email = ["bbdurand@gmail.com"]

  spec.summary = "Throttling mechanism for safely dealing with external resources so that latency does not take down your application."
  spec.homepage = "https://github.com/bdurand/double_restraint"
  spec.license = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  ignore_files = %w[
    .
    Gemfile
    Gemfile.lock
    Rakefile
    bin/
    spec/
  ]
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| ignore_files.any? { |path| f.start_with?(path) } }
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "restrainer"

  spec.add_development_dependency "bundler"

  spec.required_ruby_version = ">= 2.5"
end
