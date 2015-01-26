Gem::Specification.new do |s|
  s.name = 'gerricator'
  s.version = '0.1.2'
  s.date = Date.civil(2015,1,25)
  s.summary = 'Gerrit change to Phabricator diff'
  s.description = 'Command-line tool to create or update Phabricator diff from Gerrit change'
  s.authors = ['Jun Wu']
  s.email = 'quark@lihdd.net'
  s.homepage = 'https://github.com/quark-zju/gerricator'
  s.require_paths = ['lib']
  s.licenses = ['BSD']
  s.files = %w(LICENSE README.md gerricator.gemspec)
  s.files += Dir.glob('{bin/*,lib/*.rb,db/**/*.rb,config/*.{example,rb}}')
  s.executables = ['gerricator']
  s.add_dependency 'activerecord', '~> 4.1'
  s.add_dependency 'sqlite3', '~> 1.3'
  s.add_dependency 'thor', '~> 0.19'
  s.add_dependency 'httpi', '~> 2.2'
  s.add_dependency 'curb', '~> 0.8'
end
