#!/usr/bin/env ruby

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

# This file contains the test suite to verify the client library is working
# correctly.

$:.unshift(File.dirname(__FILE__) + '/../ext')

require 'test/unit'
require 'sedna'
require 'socket'

class SednaTest < Test::Unit::TestCase
  # Support declarative specification of test methods.
  def self.test name, &block
    test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
    defined = instance_method(test_name) rescue false
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method test_name, &block
    else
      define_method test_name do
        flunk "No implementation provided for #{test_name}"
      end
    end
  end

  unless method_defined? :method_name
    def method_name
      __method__.to_s
    end
  end

  # Setup.
  def setup
    @connection = {
      :database => "test",
      :host => "localhost",
      :username => "SYSTEM",
      :password => "MANAGER",
    }
  end

  # Faux test that just checks if we can connect, otherwise the test
  # suite is aborted.
  test "aaa connection" do
    port = 5050
    begin
      s = TCPSocket.new @connection[:host], port
    rescue Errno::ECONNREFUSED, SocketError
      # No DB appears to be running; fail fatally. Do not run the other tests and just exit.
      puts "Connection to port #{port} on #{@connection[:host]} could not be established. Check if the Sedna XML database is running before running this test suite."
      exit 1
    end
    assert s
    s.close
  end
  
  # Test Sedna.version.
  test "version should return 3 0" do
    assert_equal "3.0", Sedna.version
  end
  
  # Test Sedna.blocking?
  test "blocking should return true if ruby 18 and false if ruby 19" do
    if RUBY_VERSION < "1.9"
      assert Sedna.blocking?
    else
      assert !Sedna.blocking?
    end
  end
  
  # Test Sedna.connect.
  test "connect should return Sedna object" do
    sedna = Sedna.connect @connection
    assert_kind_of Sedna, sedna
    sedna.close
  end
  
  test "connect should raise TypeError if argument is not a Hash" do
    assert_raises TypeError do
      sedna = Sedna.connect Object.new
    end
  end

  test "connect should raise exception when host not found" do
    assert_raises Sedna::ConnectionError do
      Sedna.connect @connection.merge(:host => "non-existent-host")
    end
  end

  test "connect should raise exception when credentials are incorrect" do
    assert_raises Sedna::AuthenticationError do
      Sedna.connect @connection.merge(:username => "non-existent-user")
    end
  end
  
  test "connect should return nil on error" do
    begin
      sedna = Sedna.connect @connection.merge(:username => "non-existent-user")
    rescue
    end
    assert_nil sedna
  end
  
  test "connect should return nil if block given" do
    sedna = Sedna.connect @connection do |s| end
    assert_nil sedna
  end
  
  test "connect should close connection after block" do
    sedna = nil
    Sedna.connect @connection do |s|
      sedna = s
    end
    assert_raises Sedna::ConnectionError do
      sedna.execute "<test/>"
    end
  end
  
  test "connect should close connection if exception is raised inside block" do
    sedna = nil
    begin
      Sedna.connect @connection do |s|
        sedna = s
        raise Exception
      end
    rescue Exception
    end
    assert_raises Sedna::ConnectionError do
      sedna.execute "<test/>"
    end
  end
  
  test "connect should close connection if something is thrown inside block" do
    sedna = nil
    catch :ball do
      Sedna.connect @connection do |s|
        sedna = s
        throw :ball
      end
    end
    assert_raises Sedna::ConnectionError do
      sedna.execute "<test/>"
    end
  end
  
  test "connect should re-raise exceptions from inside block" do
    assert_raises Exception do
      Sedna.connect @connection do
        raise Exception
      end
    end
  end
  
  # Test sedna.close.
  test "close should return nil" do
    sedna = Sedna.connect @connection
    assert_nil sedna.close
  end

  test "close should fail silently if connection is already closed" do
    sedna = Sedna.connect @connection
    assert_nothing_raised do
      sedna.close
      sedna.close
    end
  end
  
  # Test sedna.execute / sedna.query.
  test "execute should raise TypeError if argument cannot be converted to String" do
    assert_raises TypeError do
      Sedna.connect @connection do |sedna|
        sedna.execute Object.new
      end
    end
  end
  
  test "execute should return nil for data structure query" do
    Sedna.connect @connection do |sedna|
      sedna.execute("drop document '#{method_name}'") rescue Sedna::Exception
      assert_nil sedna.execute("create document '#{method_name}'")
      sedna.execute("drop document '#{method_name}'") rescue Sedna::Exception
    end
  end
  
  test "execute should return array for select query" do
    Sedna.connect @connection do |sedna|
      assert_kind_of Array, sedna.execute("<test/>")
    end
  end
  
  test "execute should return array with single string for single select query" do
    Sedna.connect @connection do |sedna|
      assert_equal ["<test/>"], sedna.execute("<test/>")
    end
  end
  
  test "execute should return array with strings for select query" do
    Sedna.connect @connection do |sedna|
      assert_equal ["<test/>", "<test/>", "<test/>"], sedna.execute("<test/>, <test/>, <test/>")
    end
  end

  test "execute should fail if autocommit is false" do
    Sedna.connect @connection do |sedna|
      sedna.autocommit = false
      assert_raises Sedna::Exception do
        sedna.execute "<test/>"
      end
    end
  end
  
  test "execute should fail with Sedna::Exception for invalid statements" do
    Sedna.connect @connection do |sedna|
      assert_raises Sedna::Exception do
        sedna.execute "INVALID"
      end
    end
  end
  
  test "execute should fail with Sedna::ConnectionError if connection is closed" do
    Sedna.connect @connection do |sedna|
      sedna.close
      assert_raises Sedna::ConnectionError do
        sedna.execute "<test/>"
      end
    end
  end
  
  test "execute should strip first newline of all but first results" do
    Sedna.connect @connection do |sedna|
      sedna.execute("drop document '#{method_name}'") rescue Sedna::Exception
      sedna.execute("create document '#{method_name}'")
      sedna.execute("update insert <test><a>\n\nt</a><a>\n\nt</a><a>\n\nt</a></test> into doc('#{method_name}')")
      assert_equal ["\n\nt", "\n\nt", "\n\nt"], sedna.execute("doc('#{method_name}')/test/a/text()")
      sedna.execute("drop document '#{method_name}'") rescue Sedna::Exception
    end
  end

  test "execute should block other threads for ruby 18 and not block for ruby 19" do
    n = 5 # Amount of threads to be run. Increase for more accuracy.
    i = 10000 # Times to loop in query. Increase for more accuracy.
    threads = []
    start_times = {}
    end_times = {}
    n.times do |number|
      threads << Thread.new do
        Sedna.connect @connection do |sedna|
          start_times[number] = Time.now
          sedna.execute "for $x in 1 to #{i} where $x = 1 return <node/>"
          end_times[number] = Time.now
        end
      end
    end
    threads.each do |thread| thread.join end
    # Count the amount of time that is overlapped between threads. If the execute
    # method blocks, there should be hardly any overlap.
    time_diff = 0
    (n - 1).times do |number|
      time_diff += start_times[number + 1] - end_times[number]
    end
    if RUBY_VERSION < "1.9"
      # Blocking behaviour. The start/end times of two threads should not overlap.
      assert time_diff > 0
    else
      # We have concurrency, the execute method in the threads should have been
      # run in parallel and there should be considerable overlap in the start/end
      # times of the executed threads.
      assert time_diff < 0
    end
  end
  
  test "execute should be run in serially if called from different threads on same connection" do
    Sedna.connect @connection do |sedna|
      i = 1000
      threads = []
      exceptions = []
      Thread.abort_on_exception = true
      5.times do
        threads << Thread.new do
          begin
            sedna.execute "for $x in #{i} where $x = 1 return <node/>"
          rescue StandardError => e
            exceptions << e
          end
        end
      end
      threads.each do |thread| thread.join end
      assert_equal [], exceptions
    end
  end
  
  test "execute should quit if exception is raised in it by another thread in ruby 19" do
    Sedna.connect @connection do |sedna|
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      begin
        thread = Thread.new do
          sedna.execute "create document '#{method_name}'"
        end
        thread.raise
        thread.join
      rescue
      end
      count = sedna.execute("count(doc('$documents')//*[@name='#{method_name}'])").first.to_i
      if RUBY_VERSION < "1.9"
        assert_equal 1, count
      else
        assert_equal 0, count
      end
    end
  end
  
  test "query should be alias of execute" do
    Sedna.connect @connection do |sedna|
      assert_equal ["<test/>"], sedna.query("<test/>")
    end
  end

  # Test sedna.load_document.
  test "load_document should raise TypeError if document argument cannot be converted to String" do
    assert_raises TypeError do
      Sedna.connect @connection do |sedna|
        sedna.load_document Object.new, method_name
      end
    end
  end

  test "load_document should raise TypeError if doc_name argument cannot be converted to String" do
    assert_raises TypeError do
      Sedna.connect @connection do |sedna|
        sedna.load_document "<doc/>", Object.new
      end
    end
  end

  test "load_document should raise TypeError if col_name argument cannot be converted to String" do
    assert_raises TypeError do
      Sedna.connect @connection do |sedna|
        sedna.load_document "<doc/>", method_name, Object.new
      end
    end
  end

  test "load_document should create document in given collection" do
    Sedna.connect @connection do |sedna|
      col = "test_collection"
      doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>\n <node/>\n</document>"

      sedna.execute "create collection '#{col}'" rescue Sedna::Exception
      sedna.execute "drop document '#{method_name}' in collection '#{col}'" rescue Sedna::Exception
      sedna.load_document doc, method_name, col
      assert_equal doc, sedna.execute("doc('#{method_name}', '#{col}')").first
      sedna.execute "drop document '#{method_name}' in collection '#{col}'" rescue Sedna::Exception
      sedna.execute "drop collection '#{col}'" rescue Sedna::Exception
    end
  end

  test "load_document should create standalone document if collection is unspecified" do
    Sedna.connect @connection do |sedna|
      doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>\n <node/>\n</document>"

      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      sedna.load_document doc, method_name
      assert_equal doc, sedna.execute("doc('#{method_name}')").first
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
    end
  end
  
  test "load_document should create standalone document if collection is nil" do
    Sedna.connect @connection do |sedna|
      doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>\n <node/>\n</document>"

      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      sedna.load_document doc, method_name, nil
      assert_equal doc, sedna.execute("doc('#{method_name}')").first
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
    end
  end
  
  test "load_document should return nil if standalone document loaded successfully" do
    Sedna.connect @connection do |sedna|
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      assert_nil sedna.load_document("<document><node/></document>", method_name)
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
    end
  end

  test "load_document should fail if autocommit is false" do
    Sedna.connect @connection do |sedna|
      sedna.autocommit = false
      assert_raises Sedna::Exception do
        sedna.load_document "<test/>", "some_doc"
      end
    end
  end
  
  test "load_document should fail with Sedna::Exception for invalid documents" do
    Sedna.connect @connection do |sedna|
      assert_raises Sedna::Exception do
        sedna.load_document "<doc/> this is an invalid document", "some_doc"
      end
    end
  end
  
  test "load_document should raise exception with complete details for invalid documents" do
    Sedna.connect @connection do |sedna|
      e = nil
      begin
        sedna.load_document "<doc/> junk here", "some_doc"
      rescue Sedna::Exception => e
      end
      assert_match /junk after document element/, e.message
    end
  end
  
  test "load_document should fail with Sedna::ConnectionError if connection is closed" do
    Sedna.connect @connection do |sedna|
      sedna.close
      assert_raises Sedna::ConnectionError do
        sedna.load_document "<doc/>", "some_doc"
      end
    end
  end

  test "load_document should create document if given document is IO object" do
    Sedna.connect @connection do |sedna|
      doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>" << ("\n <some_very_often_repeated_node/>" * 800) << "\n</document>"
      p_out, p_in = IO.pipe
      p_in.write doc
      p_in.close

      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      sedna.load_document p_out, method_name, nil
      assert_equal doc.length, sedna.execute("doc('#{method_name}')").first.length
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
    end
  end

  test "load_document should raise Sedna::Exception if given document is empty IO object" do
    Sedna.connect @connection do |sedna|
      p_out, p_in = IO.pipe
      p_in.close

      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      e = nil
      begin
        sedna.load_document p_out, method_name, nil
      rescue Sedna::Exception => e
      end
      assert_equal "Document is empty.", e.message
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
    end
  end

  test "load_document should raise Sedna::Exception if given document is empty string" do
    Sedna.connect @connection do |sedna|
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      e = nil
      begin
        sedna.load_document "", method_name, nil
      rescue Sedna::Exception => e
      end
      assert_equal "Document is empty.", e.message
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
    end
  end
  
  # Test sedna.autocommit= / sedna.autocommit.
  test "autocommit should return true by default" do
    Sedna.connect @connection do |sedna|
      assert_equal true, sedna.autocommit
    end
  end
  
  test "autocommit should return true if set to true" do
    Sedna.connect @connection do |sedna|
      sedna.autocommit = true
      assert_equal true, sedna.autocommit
    end
  end
  
  test "autocommit should return false if set to false" do
    Sedna.connect @connection do |sedna|
      sedna.autocommit = false
      assert_equal false, sedna.autocommit
    end
  end
  
  test "autocommit should return true if set to true after being set to false" do
    Sedna.connect @connection do |sedna|
      sedna.autocommit = false
      sedna.autocommit = true
      assert_equal true, sedna.autocommit
    end
  end
  
  test "autocommit should return true if argument evaluates to true" do
    Sedna.connect @connection do |sedna|
      sedna.autocommit = "string evaluates to true"
      assert_equal true, sedna.autocommit
    end
  end
  
  test "autocommit should return false if argument evaluates to false" do
    Sedna.connect @connection do |sedna|
      sedna.autocommit = nil
      assert_equal false, sedna.autocommit
    end
  end
  
  test "autocommit should be re-enabled after transactions" do
    Sedna.connect @connection do |sedna|
      sedna.autocommit = true
      sedna.transaction do end
      assert_nothing_raised do
        sedna.execute "<test/>"
      end
    end
  end
  
  # Test sedna.transaction.
  test "transaction should return nil if committed" do
    Sedna.connect @connection do |sedna|
      assert_nil sedna.transaction(){}
    end
  end
  
  test "transaction should raise LocalJumpError if no block is given" do
    assert_raises LocalJumpError do
      Sedna.connect @connection do |sedna|
        sedna.transaction
      end
    end
  end
  
  test "transaction should be possible with autocommit" do
    Sedna.connect @connection do |sedna|
      sedna.autocommit = true
      assert_nothing_raised do
        sedna.transaction do end
      end
    end
  end
  
  test "transaction should fail with Sedna::TransactionError if another transaction is started inside it" do
    assert_raises Sedna::TransactionError do
      Sedna.connect @connection do |sedna|
        sedna.transaction do
          sedna.transaction do end
        end
      end
    end
  end
  
  test "transaction should commit if block given" do
    Sedna.connect @connection do |sedna|
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      sedna.execute "create document '#{method_name}'"
      sedna.transaction do
        sedna.execute "update insert <test>test</test> into doc('#{method_name}')"
      end
      assert_equal 1, sedna.execute("count(doc('#{method_name}')/test)").first.to_i
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
    end
  end

  test "transaction should rollback if exception is raised inside block" do
    Sedna.connect @connection do |sedna|
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      sedna.execute "create document '#{method_name}'"
      begin
        sedna.transaction do
          sedna.execute "update insert <test>test</test> into doc('#{method_name}')"
          raise Exception
        end
      rescue Exception
      end
      assert_equal 0, sedna.execute("count(doc('#{method_name}')/test)").first.to_i
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
    end
  end

  test "transaction should rollback if something is thrown inside block" do
    Sedna.connect @connection do |sedna|
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
      sedna.execute "create document '#{method_name}'"
      catch :ball do
        sedna.transaction do
          sedna.execute "update insert <test>test</test> into doc('#{method_name}')"
          throw :ball
        end
      end
      assert_equal 0, sedna.execute("count(doc('#{method_name}')/test)").first.to_i
      sedna.execute "drop document '#{method_name}'" rescue Sedna::Exception
    end
  end

  test "transaction should raise Sedna::TransactionError if invalid statement caused exception but it was rescued" do
    assert_raises Sedna::TransactionError do
      Sedna.connect @connection do |sedna|
        sedna.transaction do
          sedna.execute "FAILS" rescue Sedna::Exception
        end
      end
    end
  end
  
  test "transaction should re-raise exceptions from inside block" do
    Sedna.connect @connection do |sedna|
      assert_raises Exception do
        sedna.transaction do
          raise Exception
        end
      end
    end
  end

  test "transaction with invalid statements should cause transaction to roll back once" do
    exc = nil
    begin
      Sedna.connect @connection do |sedna|
        sedna.transaction do
          sedna.execute "FAILS"
        end
      end
    rescue Sedna::Exception => exc
    end
    assert_equal "It is a dynamic error if evaluation of an expression relies on some part of the dynamic context that has not been assigned a value.", exc.message
  end
  
  test "transaction should raise Sedna::TransactionError if called from different threads on same connection" do
    Sedna.connect @connection do |sedna|
      threads = []
      exceptions = []
      Thread.abort_on_exception = true
      5.times do
        threads << Thread.new do
          begin
            sedna.transaction do
              sleep 0.1
            end
          rescue StandardError => e
            exceptions << e.class
          end
        end
      end
      threads.each do |thread| thread.join end
      assert_equal [Sedna::TransactionError] * 4, exceptions
    end
  end
end
