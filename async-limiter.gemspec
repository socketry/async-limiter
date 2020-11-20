require_relative "lib/async/limiter/version"

Gem::Specification.new do |s|
  s.name = "async-limiter"
  s.version = Async::Limiter::VERSION
  s.summary = "Async limiters"
  s.author = "Bruno Sutic"
  s.email = "code@brunosutic.com"
  s.require_paths = %w[lib]
  s.files = Dir["lib/**/*"]
  s.required_ruby_version = ">= 2.7.0"
  s.homepage = "https://github.com/bruno-/async-limiter"
  s.license = "MIT"

  s.add_dependency "async", "~> 1.27"

  s.add_development_dependency "async-rspec", "~> 1.15"
  s.add_development_dependency "rspec", "~> 3.10"
  s.add_development_dependency "rubocop-rspec", "~> 2.0"
  s.add_development_dependency "standard", "~> 0.9"
end
