# frozen_string_literal: true

require_relative 'lib/vwo/constants'

Gem::Specification.new do |spec|
  spec.name          = 'vwo-sdk'
  spec.version       = VWO::CONSTANTS::SDK_VERSION
  spec.authors       = ['VWO']
  spec.email         = ['dev@wingify.com']

  spec.summary       = "Ruby SDK for VWO full-stack testing"
  spec.description   = "A Ruby SDK for VWO full-stack testing."
  spec.homepage      = 'https://vwo.com/fullstack/server-side-testing/'
  spec.license       = 'Apache 2.0'

  spec.files         = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'coveralls', '~> 0.8.23'
  spec.add_development_dependency 'rubocop', '~> 0.70'

  spec.add_runtime_dependency 'json-schema', '~> 2.8'
  spec.add_runtime_dependency 'murmurhash3', '~> 0.1'
end
