# Copyright 2008-2010 Voormedia B.V.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Ruby extension library providing a client API to the Sedna native XML
# database management system, based on the official Sedna C driver.

# This file defines how to build a Rubygem for the Sedna client library.

require 'rubygems'
require 'rdoc' # Use latest RDoc version.
require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'
require 'rake/rdoctask'

RDOC_TITLE = "Sedna XML DBMS client library for Ruby"
RDOC_FILES = FileList["[A-Z][A-Z]*", "ext/**/*.c"].to_a

task :default => [:rebuild, :test]

task :multi do
  exec "multiruby -S rake"
end

desc "Build the Ruby extension"
task :build do
  Dir.chdir "ext/sedna"
  ruby "extconf.rb"
  sh "make"
  Dir.chdir "../.."
end

desc "Remove build products"
task :clobber_build do
  sh "rm -f ext/**/*.{so,o,log,bundle}"
  sh "rm -f ext/**/Makefile"
  sh "rm -rf ext/**/conftest.*"
  system "cd vendor/sedna/driver/c && make clean"  
end

desc "Force a rebuild of the Ruby extension"
task :rebuild => [:clobber_build, :build]

Rake::TestTask.new do |t|
  t.test_files = FileList["test/*_test.rb"]
  t.verbose = true
end

gem_spec = Gem::Specification.new do |s|
  s.name = "sedna"
  s.version = "0.6.0"

  s.summary = "Sedna XML DBMS client library."
  s.description = %{Ruby extension that provides a client library for the Sedna XML DBMS, making use of the official C driver of the Sedna project.}
  s.requirements = %{Sedna XML DBMS C driver (library and headers).}
  s.author = "Rolf Timmermans"
  s.email = "r.timmermans@voormedia.com"
  s.homepage = "http://sedna.rubyforge.org/"
  s.rubyforge_project = "sedna"

  s.extensions << "ext/sedna/extconf.rb"
  s.files = FileList["Rakefile", "ext/**/extconf.rb", "ext/**/*.c", "test/**/*.rb"].to_a
  s.require_path = "lib"

  s.has_rdoc = true
  s.extra_rdoc_files = RDOC_FILES
  s.rdoc_options << "--title" << RDOC_TITLE << "--main" << "README.rdoc"
  
  s.test_files = FileList["test/**/*_test.rb"].to_a
end

Rake::GemPackageTask.new gem_spec do |p|
  p.gem_spec = gem_spec
  p.need_tar_gz = true
  p.need_zip = true
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title = RDOC_TITLE
  rdoc.rdoc_files.include *RDOC_FILES
  rdoc.main = "README"
end

namespace :driver do
  task :update do
    exit if ENV["SOURCE"].nil?
    source = File.expand_path(File.join(File.dirname(__FILE__), ENV["SOURCE"]))
    target = "vendor/sedna"
    %x(rm -rf #{target} && mkdir -p #{target}/driver && mkdir -p #{target}/kernel)

    %x(cp -r #{source}/{AUTHORS,COPYRIGHT,LICENSE} #{target})
    %x(cp -r #{source}/{depend.sed,ver,Makefile.include,Makefile.platform} #{target})
    %x(cp -r #{source}/driver/c #{target}/driver/c)
    %x(cp -r #{source}/kernel/common #{target}/kernel/common)

    u_h = File.read("#{target}/kernel/common/u/u.h")
    u_h.gsub!("#include <ucontext.h>", "")
    File.open("#{target}/kernel/common/u/u.h", "w") do |f|
      f.write u_h
    end
  end
end
