# frozen_string_literal: true

require_relative 'lib/legion/extensions/curiosity/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-curiosity'
  spec.version       = Legion::Extensions::Curiosity::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX Curiosity'
  spec.description   = 'Intrinsic curiosity engine for brain-modeled agentic AI'
  spec.homepage      = 'https://github.com/LegionIO/lex-curiosity'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/LegionIO/lex-curiosity'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-curiosity'
  spec.metadata['changelog_uri'] = 'https://github.com/LegionIO/lex-curiosity'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/LegionIO/lex-curiosity/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('{lib,spec}/**/*') + %w[lex-curiosity.gemspec Gemfile LICENSE README.md]
  end
  spec.require_paths = ['lib']
  spec.add_development_dependency 'legion-gaia'
end
