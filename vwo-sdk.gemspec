# frozen_string_literal: true

require_relative 'lib/vwo/constants'

Gem::Specification.new do |spec|
  spec.name          = 'vwo-sdk'
  spec.version       = VWO::CONSTANTS::SDK_VERSION
  spec.authors       = ['VWO']
  spec.email         = ['dev@wingify.com']

  spec.summary       = "Ruby SDK for VWO FullStack testing"
  spec.description   = "Ruby SDK for VWO FullStack testing."
  spec.homepage      = 'https://vwo.com/fullstack/server-side-testing/'
  spec.license       = 'Apache-2.0'

  spec.files         = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/wingify/vwo-ruby-sdk/issues",
    "changelog_uri"     => "https://github.com/wingify/vwo-ruby-sdk/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://developers.vwo.com/docs/ruby-sdk-reference",
    "homepage_uri"      => "https://github.com/wingify/vwo-ruby-sdk",
    "source_code_uri"   => "https://github.com/wingify/vwo-ruby-sdk"
  }

  spec.required_ruby_version = '>= 2.2.10'

  spec.add_development_dependency 'codecov', '~> 0.4.3'
  spec.add_development_dependency 'rubocop', '~> 0.70'
  spec.add_development_dependency 'mocha', '~>1.13.0'

  spec.add_runtime_dependency 'json-schema', '~> 2.8'
  spec.add_runtime_dependency 'murmurhash3', '~> 0.1'
end
