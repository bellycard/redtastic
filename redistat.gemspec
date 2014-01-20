# -*- encoding: utf-8 -*-
require File.expand_path('../lib/redistat/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name         = 'redistat'
  gem.version      = Redistat::Version
  gem.date         = '2013-01-15'
  gem.authors      = ['Joe DiVita']
  gem.email        = ['divita@bellycard.com']
  gem.description  = %q{ A simple layer on top of Redis for serving quantitative analytics }
  gem.summary      = %q{ A simple layer on top of Redis for serving quantitative analytics }
  gem.homepage     = ''
  gem.files        = ['lib/redistat.rb']

  gem.add_dependency 'redis'
  gem.add_dependency 'activesupport'

  gem.add_development_dependency 'dotenv'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'git'
  gem.add_development_dependency 'rubocop'
end
