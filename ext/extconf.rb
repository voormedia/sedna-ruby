# Copyright 2008, 2009 Voormedia B.V.
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

if RUBY_VERSION < "1.8"
  puts "This library requires ruby 1.8."
  exit 1
end

driver = "/driver/c"
default_driver_dirs = ["/usr/local/sedna#{driver}", "/opt/sedna#{driver}", File.expand_path("~/sedna#{driver}")]
default_include_dirs = ["/usr/include", "/usr/include/sedna"] + default_driver_dirs
default_lib_dirs = ["/usr/lib", "/usr/lib/sedna"] + default_driver_dirs

# If user specified directories.
idir, ldir = dir_config "sedna", nil, nil
if idir.nil? or ldir.nil?
  idir, ldir = default_include_dirs, default_lib_dirs
else
  ldir = File.expand_path(ldir.sub("/lib", driver)) unless ldir.nil?
  idir = [File.expand_path(idir), ldir] unless idir.nil?
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

if CONFIG["arch"] =~ /x86_64/i and File.exist?(f = $LIBPATH.first + File::Separator + "libsedna.a")
  if system "/usr/bin/objdump --reloc \"#{f}\" 2>/dev/null | grep R_X86_64_32S >/dev/null && echo"
    $stderr.write %{==============================================================================
Library libsedna.a was statically compiled for a 64-bit platform as position-
dependent code. It will not be possible to create a Ruby shared library with
this Sedna library. Recompile the library as position-independent code by
passing the -fPIC option to gcc.
==============================================================================
}
    exit 4
  end
end

have_func "rb_thread_blocking_region"
have_func "rb_mutex_synchronize"
have_func "rb_enc_str_buf_cat"

create_makefile "sedna"
