require 'rake'
require 'rake/rdoctask'
require 'spec/rake/spectask'

desc 'Default: run specs.'
task :default => :spec

desc "Run all specs for the buena_vista plugin."
Spec::Rake::SpecTask.new(:spec) do |t|
  #t.spec_opts = ['--options', "\"#{RAILS_ROOT}/spec/spec.opts\""]
  t.spec_opts = %w(--colour --format nested)
  t.spec_files = FileList['spec/**/*_spec.rb']
end

desc 'Generate documentation for the buena_vista plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'BuenaVista'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.md')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
