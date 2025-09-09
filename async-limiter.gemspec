# frozen_string_literal: true

require_relative "lib/async/limiter/version"

Gem::Specification.new do |spec|
	spec.name = "async-limiter"
	spec.version = Async::Limiter::VERSION
	
	spec.summary = "Execution rate limiting for Async"
	spec.authors = ["Bruno Sutic", "Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/bruno-/async-limiter"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-limiter/",
		"source_code_uri" => "https://github.com/socketry/async-limiter.git",
	}
	
	spec.files = Dir["{lib}/**/*", "*.md", base: __dir__]
	
	spec.required_ruby_version = ">= 3.2"
	
	spec.add_dependency "async"
end
