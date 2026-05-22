# frozen_string_literal: true

require_relative "lib/async/limiter/version"

Gem::Specification.new do |spec|
	spec.name = "async-limiter"
	spec.version = Async::Limiter::VERSION
	
	spec.summary = "Execution rate limiting for Async"
	spec.authors = ["Bruno Sutic", "Shopify Inc.", "Samuel Williams", "William T. Nelson", "Francisco Mejia"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/async-limiter"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-limiter/",
		"source_code_uri" => "https://github.com/socketry/async-limiter.git",
	}
	
	spec.files = Dir["{context,lib}/**/*", "*.md", base: __dir__]
	
	spec.required_ruby_version = ">= 3.3"
	
	spec.add_dependency "async", ">= 2.31"
	spec.add_dependency "async-utilization", "~> 0.4"
end
