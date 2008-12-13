# Copyright 2008 Voormedia B.V.
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


#--
# Copyright 2008 Voormedia B.V.
#++

require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/gempackagetask'
#require 'rake/rdoctask'

Rake::TestTask.new do |t|
  t.test_files = FileList["test/*_test.rb"]
  t.verbose = true
end

gem_spec = Gem::Specification.new do |s|
  s.name = "sedna"
  s.version = "0.1.1"

  s.summary = "Sedna XML DBMS client library."
  s.description = %{Ruby extension that provides a client library for the Sedna XML DBMS, making use of the official C driver of the Sedna project.}
  s.requirements = %{Sedna XML DBMS C driver (library and headers).}
  s.author = "Rolf Timmermans"
  s.email = "r.timmermans@voormedia.com"
  s.homepage = "http://sedna.rubyforge.org/"
  s.rubyforge_project = "sedna"

  s.extensions << "ext/extconf.rb"
  s.files = FileList["ext/extconf.rb", "ext/**/*.c", "test/**/*.rb"].to_a
  s.require_path = "lib"

  s.has_rdoc = true
  s.extra_rdoc_files = FileList["[A-Z][A-Z]*", "ext/**/*.c"].to_a
  s.rdoc_options << "--title" << "Sedna XML DBMS client library for Ruby" << "--main" << "README"
  
  s.test_files = FileList["test/**/*_test.rb"].to_a
end

Rake::GemPackageTask.new gem_spec do |p|
  p.gem_spec = gem_spec
  p.need_tar_gz = true
  p.need_zip = true
end
