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

# This file will generate a Makefile that can be used to build this extension.

require "mkmf"

# Fail for old Rubies.
if RUBY_VERSION < "1.8"
  puts "This library requires ruby 1.8."
  exit 1
end

def set_arch(arch)
  flags = "-arch #{arch}"
  $CFLAGS.gsub!(/-arch\s+\S+ /, "")
  $LDFLAGS.gsub!(/-arch\s+\S+ /, "")
  CONFIG['LDSHARED'].gsub!(/-arch\s+\S+ /, "")

  $CFLAGS << " " << flags
  $LDFLAGS << " " << flags
  CONFIG["LDSHARED"] << " " << flags
end

DRIVER = "/driver/c"

idir, ldir = dir_config "sedna", nil, nil
if idir.nil? or ldir.nil?
  driver_dir = File.expand_path("#{File.dirname(__FILE__)}/../../vendor/sedna/#{DRIVER}")

  # Compile bundled driver.
  system "cd #{driver_dir} && make clean && make"
  
  # Link to bundled driver.
  idir = ldir = [driver_dir]
else
  # Use user-specified driver.
  ldir = File.expand_path(ldir.sub("/lib", DRIVER)) unless ldir.nil?
  idir = [File.expand_path(idir), ldir] unless idir.nil?
end

# Fix multiple arch flags on Mac OS X.
if RUBY_PLATFORM.include?("darwin")
  ldir.each do |libdir|
    if File.exists?("#{libdir}/libsedna.a") and %x(which lipo && lipo -info #{libdir}/libsedna.a) =~ /architecture: (.+)$/
      set_arch($1) unless $1 == "i386"
      break
    end
  end
end

if not find_library "sedna", "SEconnect", *ldir
  $stderr.write %{
==============================================================================
Could not find libsedna.

* Did you install Sedna in a non default location? Call extconf.rb
  with --with-sedna-dir=/path/to/sedna to override it. With rubygems:

    gem install sedna -- --with-sedna-dir=/path/to/sedna

* Did you install a version of Sedna not compiled for your architecture?
  The standard Sedna distribution of Sedna is compiled for i386. If your
  platform is x86_64, and your Ruby was compiled as x86_64, you must
  recompile Sedna for x86_64 as well. Download the sources at:
  
    http://modis.ispras.ru/sedna/download.html
==============================================================================
}
  exit 2
end

if not find_header "libsedna.h", *idir or not find_header "sp_defs.h", *idir
  $stderr.write %{
==============================================================================
Could not find header file(s) for libsedna.

* Did you install Sedna in a non default location? Call extconf.rb
  with --with-sedna-dir=/path/to/sedna to override it. With rubygems:

    gem install sedna -- --with-sedna-dir=/path/to/sedna

==============================================================================
}
  exit 3
end

have_func "rb_thread_blocking_region"
have_func "rb_mutex_synchronize"
have_func "rb_enc_str_buf_cat"

create_makefile "sedna"
