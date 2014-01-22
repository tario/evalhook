require 'rubygems'
require 'rake'
require 'rdoc/task'
require 'rubygems/package_task'
require 'rake/testtask'

spec = Gem::Specification.new do |s|
  s.name = 'evalhook'
  s.version = '0.5.8'
  s.author = 'Dario Seminara'
  s.email = 'robertodarioseminara@gmail.com'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Alternate eval which hook all methods executed in the evaluated code'
  s.homepage = "http://github.com/tario/evalhook"
  s.add_dependency "partialruby", "~> 0.3"
  s.add_dependency "sexp_processor", "~> 4.0"
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
Gem::PackageTask.new spec do |pkg|
  pkg.need_tar = true
end

desc 'Clean up'
task :clean => [ :clobber_rdoc, :clobber_package ]

desc 'Clean up'
task :clobber => [ :clean ]
