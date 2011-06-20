require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = 'evalhook'
  s.version = '0.5.0'
  s.author = 'Dario Seminara'
  s.email = 'robertodarioseminara@gmail.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Alternate eval which hook all methods executed in the evaluated code'
  s.homepage = "http://github.com/tario/evalhook"
  s.add_dependency "partialruby", ">= 0.2.0"
  s.add_dependency "ruby_parser", ">= 2.0.6"
  s.has_rdoc = true
  s.extra_rdoc_files = [ 'README' ]
  s.rdoc_options << '--main' << 'README'
  s.files = Dir.glob("{examples,lib,spec}/**/*.rb") +
    [ 'LICENSE', 'AUTHORS', 'CHANGELOG', 'README', 'Rakefile', 'TODO' ]
end

desc 'Run tests'
task :default => [ :test ]

Rake::TestTask.new('test') do |t|
  t.libs << 'test'
  t.pattern = '{test}/**/test_*.rb'
  t.verbose = true
end

desc 'Generate RDoc'
Rake::RDocTask.new :rdoc do |rd|
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.add 'lib', 'README'
  rd.main = 'README'
end

desc 'Build Gem'
Rake::GemPackageTask.new spec do |pkg|
  pkg.need_tar = true
end

desc 'Clean up'
task :clean => [ :clobber_rdoc, :clobber_package ]

desc 'Clean up'
task :clobber => [ :clean ]
