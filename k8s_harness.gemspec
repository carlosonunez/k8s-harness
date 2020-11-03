# frozen_string_literal: true

require 'kramdown'

Gem::Specification.new do |s|
  s.name = 'k8s-harness'
  s.required_ruby_version = '~> 2.7.0'
  s.executables << 'k8s-harness'
  s.version     = File.read('VERSION')
  s.date        = '2020-10-28'
  s.summary     = 'Test your apps in disposable, prod-like Kubernetes clusters'
  s.description = 'Please visit the README in the Github repo linked to this gem for more info.'
  s.authors     = ['Carlos Nunez']
  s.email       = 'dev@carlosnunez.me'
  s.files       = Dir['./lib/**/*.rb', './include/**', './conf/**']
  s.homepage    = 'https://github.com/carlosonunez/k8s-harness'
  s.license = 'MIT'
end
