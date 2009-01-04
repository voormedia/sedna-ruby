#!/usr/bin/env ruby
# encoding: utf-8

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
    define_method "test_#{name.gsub(/\s+/,'_')}".to_sym, &block
  end

  # Backward compatibility if __method__ is not available.
  alias :__method__ :method_name if method_defined? :method_name
  
  @@spec = {
    :database => "test",
    :host => "localhost",
    :username => "SYSTEM",
    :password => "MANAGER",
  }

  # Test the remote socket before continuing.
  port = 5050
  begin
    socket = TCPSocket.new @@spec[:host], port
  rescue Errno::ECONNREFUSED, SocketError
    # No DB appears to be running; fail fatally. Do not run the other tests and just exit.
    puts "\nConnection to port #{port} on #{@@spec[:host]} could not be established.\nCheck if the Sedna XML database is running before running this test suite.\n\n"
    exit 1
  end
  socket.close
  
  # Create re-usable connection. Word of warning: because we re-use the connection,
  # if one particular test screws it up, subsequent tests may fail.
  @@sedna = Sedna.connect @@spec

  # Test Sedna.version.
  test "version should return 3.0" do
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
    sedna = Sedna.connect @@spec
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
      Sedna.connect @@spec.merge(:host => "non-existent-host")
    end
  end

  test "connect should raise exception when credentials are incorrect" do
    assert_raises Sedna::AuthenticationError do
      Sedna.connect @@spec.merge(:username => "non-existent-user")
    end
  end
  
  test "connect should return nil on error" do
    begin
      sedna = Sedna.connect @@spec.merge(:username => "non-existent-user")
    rescue
    end
    assert_nil sedna
  end
  
  test "connect should not execute block if connection fails" do
    assert_nothing_raised do
      sedna = Sedna.connect @@spec.merge(:username => "non-existent-user") do
        raise "block should not be run"
      end rescue nil
    end
  end
  
  test "connect should return nil if block given" do
    sedna = Sedna.connect @@spec do |s| end
    assert_nil sedna
  end
  
  test "connect should close connection after block" do
    sedna = nil
    Sedna.connect @@spec do |s|
      sedna = s
    end
    assert_raises Sedna::ConnectionError do
      sedna.execute "<test/>"
    end
  end
  
  test "connect should close connection if exception is raised inside block" do
    sedna = nil
    begin
      Sedna.connect @@spec do |s|
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
      Sedna.connect @@spec do |s|
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
      Sedna.connect @@spec do
        raise Exception
      end
    end
  end
  
  test "connect should set instance variables for keys in connection specification" do
    assert_equal @@spec.values, @@spec.keys.collect { |k| @@sedna.instance_variable_get "@#{k.to_s}".to_sym }
  end
  
  # Test sedna.close.
  test "close should return nil" do
    sedna = Sedna.connect @@spec
    assert_nil sedna.close
  end

  test "close should fail silently if connection is already closed" do
    sedna = Sedna.connect @@spec
    assert_nothing_raised do
      sedna.close
      sedna.close
    end
  end
  
  # Test sedna.connected?.
  test "connected? should return true if connected" do
    assert_equal true, @@sedna.connected?
  end
  
  test "connected? should return false if closed" do
    sedna = Sedna.connect @@spec
    sedna.close
    assert_equal false, sedna.connected?
  end
  
  # Test sedna.reset.
  test "reset should return nil" do
    assert_nil @@sedna.reset
  end
  
  test "reset should break current transaction" do
    assert_raises Sedna::TransactionError do
      @@sedna.transaction do
        @@sedna.reset
      end
    end
  end
  
  test "reset should implicitly roll back current transaction" do
    @@sedna.execute "drop document '#{__method__}'" rescue nil
    @@sedna.execute "create document '#{__method__}'"
    @@sedna.transaction do
      @@sedna.execute "update insert <test>test</test> into doc('#{__method__}')"
      @@sedna.reset
    end rescue nil
    assert_equal 0, @@sedna.execute("count(doc('#{__method__}')/test)").first.to_i
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end
  
  test "reset should close and reconnect if the connection is open" do
    @@sedna.reset
    assert_nothing_raised do
      @@sedna.execute "<test/>"
    end
  end
  
  test "reset should reconnect if the connection is closed" do
    @@sedna.close
    @@sedna.reset
    assert_nothing_raised do
      @@sedna.execute "<test/>"
    end
  end

  test "reset should raise exception when host not found" do
    sedna = Sedna.connect @@spec
    sedna.instance_variable_set :@host, "non-existent-host"
    assert_raises Sedna::ConnectionError do
      sedna.reset
    end
  end

  test "reset should raise exception when credentials are incorrect" do
    sedna = Sedna.connect @@spec
    sedna.instance_variable_set :@username, "non-existent-user"
    assert_raises Sedna::AuthenticationError do
      sedna.reset
    end
  end

  test "reset should preserve disabled autocommit status" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = false
      sedna.reset
      assert_raises Sedna::Exception do
        sedna.execute "<test/>"
     end
    end
  end
  
  # Test sedna.execute / sedna.query.
  test "execute should raise TypeError if argument cannot be converted to String" do
    assert_raises TypeError do
      @@sedna.execute Object.new
    end
  end
  
  test "execute should return nil for data structure query" do
    @@sedna.execute("drop document '#{__method__}'") rescue nil
    assert_nil @@sedna.execute("create document '#{__method__}'")
    @@sedna.execute("drop document '#{__method__}'") rescue nil
  end
  
  test "execute should return subclass of array for select query" do
    assert_kind_of Array, @@sedna.execute("<test/>")
  end
  
  test "execute should return array with single string for single select query" do
    assert_equal ["<test/>"], @@sedna.execute("<test/>")
  end
  
  test "execute should return array with strings for select query" do
    assert_equal ["<test/>", "<test/>", "<test/>"], @@sedna.execute("<test/>, <test/>, <test/>")
  end
  
  test "execute should return tainted strings" do
    assert @@sedna.execute("<test/>").first.tainted?
  end

  test "execute should fail if autocommit is false" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = false
      assert_raises Sedna::Exception do
        sedna.execute "<test/>"
      end
    end
  end
  
  test "execute should fail with Sedna::Exception for invalid statements" do
    assert_raises Sedna::Exception do
      @@sedna.execute "INVALID"
    end
  end
  
  test "execute should fail with Sedna::ConnectionError if connection is closed" do
    Sedna.connect @@spec do |sedna|
      sedna.close
      assert_raises Sedna::ConnectionError do
        sedna.execute "<test/>"
      end
    end
  end
  
  test "execute should strip first newline of all but first results" do
    @@sedna.execute("drop document '#{__method__}'") rescue nil
    @@sedna.execute("create document '#{__method__}'")
    @@sedna.execute("update insert <test><a>\n\nt</a><a>\n\nt</a><a>\n\nt</a></test> into doc('#{__method__}')")
    assert_equal ["\n\nt", "\n\nt", "\n\nt"], @@sedna.execute("doc('#{__method__}')/test/a/text()")
    @@sedna.execute("drop document '#{__method__}'") rescue nil
  end

  test "execute should block other threads for ruby 18 and not block for ruby 19" do
    n = 5 # Amount of threads to be run. Increase for more accuracy.
    i = 10000 # Times to loop in query. Increase for more accuracy.
    threads = []
    start_times = {}
    end_times = {}
    n.times do |number|
      threads << Thread.new do
        Sedna.connect @@spec do |sedna|
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
    i = 1000
    threads = []
    exceptions = []
    Thread.abort_on_exception = true
    5.times do
      threads << Thread.new do
        begin
          @@sedna.execute "for $x in #{i} where $x = 1 return <node/>"
        rescue StandardError => e
          exceptions << e
        end
      end
    end
    threads.each do |thread| thread.join end
    assert_equal [], exceptions
  end
  
  test "execute should quit if exception is raised in it by another thread in ruby 19" do
    @@sedna.execute "drop document '#{__method__}'" rescue nil
    begin
      thread = Thread.new do
        @@sedna.execute "create document '#{__method__}'"
      end
      thread.raise
      thread.join
    rescue
    end
    count = @@sedna.execute("count(doc('$documents')//*[@name='#{__method__}'])").first.to_i
    if RUBY_VERSION < "1.9"
      assert_equal 1, count
    else
      assert_equal 0, count
    end
  end
  
  test "query should be alias of execute" do
    assert_equal ["<test/>"], @@sedna.query("<test/>")
  end

  # Test sedna.load_document.
  test "load_document should raise TypeError if document argument cannot be converted to String" do
    assert_raises TypeError do
      @@sedna.load_document Object.new, __method__.to_s
    end
  end

  test "load_document should raise TypeError if doc_name argument cannot be converted to String" do
    assert_raises TypeError do
      @@sedna.load_document "<doc/>", Object.new
    end
  end

  test "load_document should raise TypeError if col_name argument cannot be converted to String" do
    assert_raises TypeError do
      @@sedna.load_document "<doc/>", __method__.to_s, Object.new
    end
  end

  test "load_document should create document in given collection" do
    col = "test_collection"
    doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>\n <node/>\n</document>"
    @@sedna.execute "create collection '#{col}'" rescue nil
    @@sedna.execute "drop document '#{__method__}' in collection '#{col}'" rescue nil
    @@sedna.load_document doc, __method__.to_s, col
    assert_equal doc, @@sedna.execute("doc('#{__method__}', '#{col}')").first
    @@sedna.execute "drop document '#{__method__}' in collection '#{col}'" rescue nil
    @@sedna.execute "drop collection '#{col}'" rescue nil
  end

  test "load_document should create standalone document if collection is unspecified" do
    doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>\n <node/>\n</document>"
    @@sedna.execute "drop document '#{__method__}'" rescue nil
    @@sedna.load_document doc, __method__.to_s
    assert_equal doc, @@sedna.execute("doc('#{__method__}')").first
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end
  
  test "load_document should create standalone document if collection is nil" do
    doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>\n <node/>\n</document>"
    @@sedna.execute "drop document '#{__method__}'" rescue nil
    @@sedna.load_document doc, __method__.to_s, nil
    assert_equal doc, @@sedna.execute("doc('#{__method__}')").first
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end
  
  test "load_document should return nil if standalone document loaded successfully" do
    @@sedna.execute "drop document '#{__method__}'" rescue nil
    assert_nil @@sedna.load_document("<document><node/></document>", __method__.to_s)
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end

  test "load_document should fail if autocommit is false" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = false
      assert_raises Sedna::Exception do
        sedna.load_document "<test/>", "some_doc"
      end
    end
  end
  
  test "load_document should fail with Sedna::Exception for invalid documents" do
    assert_raises Sedna::Exception do
      @@sedna.load_document "<doc/> this is an invalid document", "some_doc"
    end
  end
  
  test "load_document should raise exception with complete details for invalid documents" do
    e = nil
    begin
      @@sedna.load_document "<doc/> junk here", "some_doc"
    rescue Sedna::Exception => e
    end
    assert_match /junk after document element/, e.message
  end
  
  test "load_document should fail with Sedna::ConnectionError if connection is closed" do
    Sedna.connect @@spec do |sedna|
      sedna.close
      assert_raises Sedna::ConnectionError do
        sedna.load_document "<doc/>", "some_doc"
      end
    end
  end

  test "load_document should create document if given document is IO object" do
    doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>" << ("\n <some_very_often_repeated_node/>" * 800) << "\n</document>"
    p_out, p_in = IO.pipe
    p_in.write doc
    p_in.close

    @@sedna.execute "drop document '#{__method__}'" rescue nil
    @@sedna.load_document p_out, __method__.to_s, nil
    assert_equal doc.length, @@sedna.execute("doc('#{__method__}')").first.length
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end

  test "load_document should raise Sedna::Exception if given document is empty IO object" do
    p_out, p_in = IO.pipe
    p_in.close

    @@sedna.execute "drop document '#{__method__}'" rescue nil
    e = nil
    begin
      @@sedna.load_document p_out, __method__.to_s, nil
    rescue Sedna::Exception => e
    end
    assert_equal "Document is empty.", e.message
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end

  test "load_document should raise Sedna::Exception if given document is empty string" do
    @@sedna.execute "drop document '#{__method__}'" rescue nil
    e = nil
    begin
      @@sedna.load_document "", __method__.to_s, nil
    rescue Sedna::Exception => e
    end
    assert_equal "Document is empty.", e.message
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end
  
  # Test sedna.autocommit= / sedna.autocommit.
  test "autocommit should return true by default" do
    assert_equal true, @@sedna.autocommit
  end
  
  test "autocommit should return true if set to true" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = true
      assert_equal true, sedna.autocommit
    end
  end
  
  test "autocommit should return false if set to false" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = false
      assert_equal false, sedna.autocommit
    end
  end
  
  test "autocommit should return true if set to true after being set to false" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = false
      sedna.autocommit = true
      assert_equal true, sedna.autocommit
    end
  end
  
  test "autocommit should return true if argument evaluates to true" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = "string evaluates to true"
      assert_equal true, sedna.autocommit
    end
  end
  
  test "autocommit should return false if argument evaluates to false" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = nil
      assert_equal false, sedna.autocommit
    end
  end
  
  test "autocommit should be re-enabled after a transaction" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = true
      sedna.transaction do end
      assert_nothing_raised do
        sedna.execute "<test/>"
      end
    end
  end
  
  test "autocommit should be re-enabled after a transaction was rolled back" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = true
      catch :rollback do
        sedna.transaction do
          throw :rollback
        end
      end
      assert_nothing_raised do
        sedna.execute "<test/>"
      end
    end
  end
  
  test "autocommit should be re-enabled after a transaction raised an error" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = true
      sedna.transaction do
        sedna.execute "INVALID" rescue nil
      end rescue nil
      assert_nothing_raised do
        sedna.execute "<test/>"
      end
    end
  end
  
  # Test sedna.transaction.
  test "transaction should return nil if committed" do
    assert_nil @@sedna.transaction(){}
  end
  
  test "transaction should raise LocalJumpError if no block is given" do
    assert_raises LocalJumpError do
      @@sedna.transaction
    end
  end
  
  test "transaction should be possible with autocommit" do
    Sedna.connect @@spec do |sedna|
      sedna.autocommit = true
      assert_nothing_raised do
        sedna.transaction do end
      end
    end
  end
  
  test "transaction should fail with Sedna::TransactionError if another transaction is started inside it" do
    assert_raises Sedna::TransactionError do
      @@sedna.transaction do
        @@sedna.transaction do end
      end
    end
  end
  
  test "transaction should commit if block given" do
    @@sedna.execute "drop document '#{__method__}'" rescue nil
    @@sedna.execute "create document '#{__method__}'"
    @@sedna.transaction do
      @@sedna.execute "update insert <test>test</test> into doc('#{__method__}')"
    end
    assert_equal 1, @@sedna.execute("count(doc('#{__method__}')/test)").first.to_i
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end

  test "transaction should rollback if exception is raised inside block" do
    @@sedna.execute "drop document '#{__method__}'" rescue nil
    @@sedna.execute "create document '#{__method__}'"
    begin
      @@sedna.transaction do
        @@sedna.execute "update insert <test>test</test> into doc('#{__method__}')"
        raise Exception
      end
    rescue Exception
    end
    assert_equal 0, @@sedna.execute("count(doc('#{__method__}')/test)").first.to_i
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end

  test "transaction should rollback if something is thrown inside block" do
    @@sedna.execute "drop document '#{__method__}'" rescue nil
    @@sedna.execute "create document '#{__method__}'"
    catch :ball do
      @@sedna.transaction do
        @@sedna.execute "update insert <test>test</test> into doc('#{__method__}')"
        throw :ball
      end
    end
    assert_equal 0, @@sedna.execute("count(doc('#{__method__}')/test)").first.to_i
    @@sedna.execute "drop document '#{__method__}'" rescue nil
  end

  test "transaction should raise Sedna::TransactionError if invalid statement caused exception but it was rescued" do
    assert_raises Sedna::TransactionError do
      @@sedna.transaction do
        @@sedna.execute "FAILS" rescue nil
      end
    end
  end
  
  test "transaction should re-raise exceptions from inside block" do
    assert_raises Exception do
      @@sedna.transaction do
        raise Exception
      end
    end
  end

  test "transaction with invalid statements should cause transaction to roll back once" do
    exc = nil
    begin
      @@sedna.transaction do
        @@sedna.execute "FAILS"
      end
    rescue Sedna::Exception => exc
    end
    assert_equal "It is a dynamic error if evaluation of an expression relies on some part of the dynamic context that has not been assigned a value.", exc.message
  end
  
  test "transaction should raise Sedna::TransactionError if called from different threads on same connection" do
    threads = []
    exceptions = []
    Thread.abort_on_exception = true
    5.times do
      threads << Thread.new do
        begin
          @@sedna.transaction do
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

  test "transaction should raise Sedna::Exception if connection is closed before it could be committed" do
    sedna = Sedna.connect @@spec
    assert_raises Sedna::Exception do
      sedna.transaction do
        sedna.execute "<test/>"
        sedna.close
      end
    end
  end
end
