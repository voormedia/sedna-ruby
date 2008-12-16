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
  def setup
    @connection = {
      :database => "test",
      :host => "localhost",
      :username => "SYSTEM",
      :password => "MANAGER",
    }
  end
  
  def teardown
  end

  # Faux test that just checks if we can connect, otherwise the test
  # suite is aborted.
  def test_aaa_connection
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
  
  # Test Sedna.connect.
  def test_connect_should_return_sedna_object
    sedna = Sedna.connect @connection
    assert_kind_of Sedna, sedna
    sedna.close
  end

  def test_connect_should_raise_exception_when_host_not_found
    assert_raises Sedna::ConnectionError do
      Sedna.connect @connection.merge(:host => "non-existent-host")
    end
  end

  def test_connect_should_raise_exception_when_credentials_are_incorrect
    assert_raises Sedna::AuthenticationError do
      Sedna.connect @connection.merge(:username => "non-existent-user")
    end
  end
  
  def test_connect_should_return_nil_on_error
    begin
      sedna = Sedna.connect @connection.merge(:username => "non-existent-user")
    rescue
    end
    assert_nil sedna
  end
  
  def test_connect_should_return_nil_if_block_given
    sedna = Sedna.connect @connection do |s| end
    assert_nil sedna
  end
  
  def test_connect_should_close_connection_after_block
    sedna = nil
    Sedna.connect @connection do |s|
      sedna = s
    end
    assert_raises Sedna::ConnectionError do
      sedna.execute "<test/>"
    end
  end
  
  def test_connect_should_close_connection_if_exception_is_raised_inside_block
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
  
  def test_connect_should_close_connection_if_something_is_thrown_inside_block
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
  
  def test_connect_should_reraise_exceptions_from_inside_block
    assert_raises Exception do
      Sedna.connect @connection do
        raise Exception
      end
    end
  end
  
  # Test sedna.close.
  def test_close_should_return_nil
    sedna = Sedna.connect @connection
    assert_nil sedna.close
  end

  def test_close_should_fail_silently_if_connection_is_already_closed
    sedna = Sedna.connect @connection
    assert_nothing_raised do
      sedna.close
      sedna.close
    end
  end
  
  # Test sedna.execute / sedna.query.
  def test_execute_should_return_nil_for_data_structure_query
    Sedna.connect @connection do |sedna|
      name = "test_execute_should_return_nil_for_create_document_query"
      sedna.execute("drop document '#{name}'") rescue Sedna::Exception
      assert_nil sedna.execute("create document '#{name}'")
      sedna.execute("drop document '#{name}'") rescue Sedna::Exception
    end
  end
  
  def test_execute_should_return_array_for_select_query
    Sedna.connect @connection do |sedna|
      assert_kind_of Array, sedna.execute("<test/>")
    end
  end
  
  def test_execute_should_return_array_with_single_string_for_single_select_query
    Sedna.connect @connection do |sedna|
      assert_equal ["<test/>"], sedna.execute("<test/>")
    end
  end
  
  def test_execute_should_return_array_with_strings_for_select_query
    Sedna.connect @connection do |sedna|
      assert_equal ["<test/>", "<test/>", "<test/>"], sedna.execute("<test/>, <test/>, <test/>")
    end
  end

  def test_execute_should_fail_if_autocommit_is_false
    Sedna.connect @connection do |sedna|
      sedna.autocommit = false
      assert_raises Sedna::Exception do
        sedna.execute "<test/>"
      end
    end
  end
  
  def test_execute_should_fail_with_sedna_exception_for_invalid_statments
    Sedna.connect @connection do |sedna|
      assert_raises Sedna::Exception do
        sedna.execute "INVALID"
      end
    end
  end
  
  def test_execute_should_fail_with_sedna_connection_error_if_connection_is_closed
    Sedna.connect @connection do |sedna|
      sedna.close
      assert_raises Sedna::ConnectionError do
        sedna.execute "<test/>"
      end
    end
  end
  
  def test_execute_should_strip_first_newline_of_all_but_first_results
    Sedna.connect @connection do |sedna|
      name = "test_execute_should_strip_first_newline_of_all_but_first_results"
      sedna.execute("drop document '#{name}'") rescue Sedna::Exception
      sedna.execute("create document '#{name}'")
      sedna.execute("update insert <test><a>\n\nt</a><a>\n\nt</a><a>\n\nt</a></test> into doc('#{name}')")
      assert_equal ["\n\nt", "\n\nt", "\n\nt"], sedna.execute("doc('#{name}')/test/a/text()")
      sedna.execute("drop document '#{name}'") rescue Sedna::Exception
    end
  end

  def test_execute_should_block_for_ruby_18_and_not_block_for_ruby_19
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
  
  def test_query_should_be_alias_of_execute
    Sedna.connect @connection do |sedna|
      assert_equal ["<test/>"], sedna.query("<test/>")
    end
  end

  # Test sedna.load_document.
  def test_load_document_should_create_document_in_given_collection
    Sedna.connect @connection do |sedna|
      name = "test_load_document_should_create_document_in_given_collection"
      col = "test_collection"
      doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>\n <node/>\n</document>"

      sedna.execute "create collection '#{col}'" rescue Sedna::Exception
      sedna.execute "drop document '#{name}' in collection '#{col}'" rescue Sedna::Exception
      sedna.load_document doc, name, col
      assert_equal doc, sedna.execute("doc('#{name}', '#{col}')").first
      sedna.execute "drop document '#{name}' in collection '#{col}'" rescue Sedna::Exception
      sedna.execute "drop collection '#{col}'" rescue Sedna::Exception
    end
  end

  def test_load_document_should_create_standalone_document_if_collection_is_unspecified
    Sedna.connect @connection do |sedna|
      name = "test_load_document_should_create_standalone_document_if_collection_is_unspecified"
      doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>\n <node/>\n</document>"

      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
      sedna.load_document doc, name
      assert_equal doc, sedna.execute("doc('#{name}')").first
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
    end
  end
  
  def test_load_document_should_create_standalone_document_if_collection_is_nil
    Sedna.connect @connection do |sedna|
      name = "test_load_document_should_create_standalone_document_if_collection_is_unspecified"
      doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>\n <node/>\n</document>"

      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
      sedna.load_document doc, name, nil
      assert_equal doc, sedna.execute("doc('#{name}')").first
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
    end
  end
  
  def test_load_document_should_return_nil_if_standalone_document_loaded_successfully
    Sedna.connect @connection do |sedna|
      name = "test_load_document_should_return_nil_if_document_loaded_successfully"
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
      assert_nil sedna.load_document("<document><node/></document>", name)
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
    end
  end

  def test_load_document_should_fail_if_autocommit_is_false
    Sedna.connect @connection do |sedna|
      sedna.autocommit = false
      assert_raises Sedna::Exception do
        sedna.load_document "<test/>", "some_doc"
      end
    end
  end
  
  def test_load_document_should_fail_with_sedna_exception_for_invalid_documents
    Sedna.connect @connection do |sedna|
      assert_raises Sedna::Exception do
        sedna.load_document "<doc/> this is an invalid document", "some_doc"
      end
    end
  end
  
  def test_load_document_should_raise_exception_with_complete_details_for_invalid_documents
    Sedna.connect @connection do |sedna|
      e = nil
      begin
        sedna.load_document "<doc/> junk here", "some_doc"
      rescue Sedna::Exception => e
      end
      assert_match /junk after document element/, e.message
    end
  end
  
  def test_load_document_should_fail_with_sedna_connection_error_if_connection_is_closed
    Sedna.connect @connection do |sedna|
      sedna.close
      assert_raises Sedna::ConnectionError do
        sedna.load_document "<doc/>", "some_doc"
      end
    end
  end

  def test_load_document_should_create_document_if_given_document_is_io_object
    Sedna.connect @connection do |sedna|
      name = "test_load_document_should_create_document_if_given_document_is_io_object"
      doc = "<?xml version=\"1.0\" standalone=\"yes\"?><document>" << ("\n <some_very_often_repeated_node/>" * 800) << "\n</document>"
      p_out, p_in = IO.pipe
      p_in.write doc
      p_in.close

      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
      sedna.load_document p_out, name, nil
      assert_equal doc.length, sedna.execute("doc('#{name}')").first.length
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
    end
  end

  def test_load_document_should_raise_sedna_exception_if_given_document_is_empty_io_object
    Sedna.connect @connection do |sedna|
      name = "test_load_document_should_raise_sedna_exception_if_given_document_is_empty_io_object"
      p_out, p_in = IO.pipe
      p_in.close

      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
      e = nil
      begin
        sedna.load_document p_out, name, nil
      rescue Sedna::Exception => e
      end
      assert_equal "Document is empty.", e.message
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
    end
  end

  def test_load_document_should_raise_sedna_exception_if_given_document_is_empty_string
    Sedna.connect @connection do |sedna|
      name = "test_load_document_should_raise_sedna_exception_if_given_document_is_empty_string"
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
      e = nil
      begin
        sedna.load_document "", name, nil
      rescue Sedna::Exception => e
      end
      assert_equal "Document is empty.", e.message
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
    end
  end
  
  # Test sedna.autocommit= / sedna.autocommit.
  def test_autocommit_should_return_true_by_default
    Sedna.connect @connection do |sedna|
      assert_equal true, sedna.autocommit
    end
  end
  
  def test_autocommit_should_return_true_if_set_to_true
    Sedna.connect @connection do |sedna|
      sedna.autocommit = true
      assert_equal true, sedna.autocommit
    end
  end
  
  def test_autocommit_should_return_false_if_set_to_false
    Sedna.connect @connection do |sedna|
      sedna.autocommit = false
      assert_equal false, sedna.autocommit
    end
  end
  
  def test_autocommit_should_return_true_if_set_to_true_after_being_set_to_false
    Sedna.connect @connection do |sedna|
      sedna.autocommit = false
      sedna.autocommit = true
      assert_equal true, sedna.autocommit
    end
  end
  
  def test_autocommit_should_return_true_if_argument_evaluates_to_true
    Sedna.connect @connection do |sedna|
      sedna.autocommit = "string evaluates to true"
      assert_equal true, sedna.autocommit
    end
  end
  
  def test_autocommit_should_return_false_if_argument_evaluates_to_false
    Sedna.connect @connection do |sedna|
      sedna.autocommit = nil
      assert_equal false, sedna.autocommit
    end
  end
  
  def test_autocommit_should_be_reenabled_after_transactions
    Sedna.connect @connection do |sedna|
      sedna.autocommit = true
      sedna.transaction do end
      assert_nothing_raised do
        sedna.execute "<test/>"
      end
    end
  end
  
  # Test sedna.transaction.
  def test_transaction_should_return_nil_if_committed
    Sedna.connect @connection do |sedna|
      assert_nil sedna.transaction(){}
    end
  end
  
  def test_transaction_should_raise_localjumperror_if_no_block_is_given
    assert_raises LocalJumpError do
      Sedna.connect @connection do |sedna|
        sedna.transaction
      end
    end
  end
  
  def test_transaction_should_be_possible_with_autocommit
    Sedna.connect @connection do |sedna|
      sedna.autocommit = true
      assert_nothing_raised do
        sedna.transaction do end
      end
    end
  end
  
  def test_transaction_should_fail_with_transaction_error_if_another_transaction_is_started_inside_it
    assert_raises Sedna::TransactionError do
      Sedna.connect @connection do |sedna|
        sedna.transaction do
          sedna.transaction do end
        end
      end
    end
  end
  
  def test_transaction_should_commit_if_block_given
    Sedna.connect @connection do |sedna|
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
      sedna.execute "create document '#{name}'"
      sedna.transaction do
        sedna.execute "update insert <test>test</test> into doc('#{name}')"
      end
      assert_equal 1, sedna.execute("count(doc('#{name}')/test)").first.to_i
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
    end
  end

  def test_transaction_should_rollback_if_exception_is_raised_inside_block
    Sedna.connect @connection do |sedna|
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
      sedna.execute "create document '#{name}'"
      begin
        sedna.transaction do
          sedna.execute "update insert <test>test</test> into doc('#{name}')"
          raise Exception
        end
      rescue Exception
      end
      assert_equal 0, sedna.execute("count(doc('#{name}')/test)").first.to_i
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
    end
  end

  def test_transaction_should_rollback_if_something_is_thrown_inside_block
    Sedna.connect @connection do |sedna|
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
      sedna.execute "create document '#{name}'"
      catch :ball do
        sedna.transaction do
          sedna.execute "update insert <test>test</test> into doc('#{name}')"
          throw :ball
        end
      end
      assert_equal 0, sedna.execute("count(doc('#{name}')/test)").first.to_i
      sedna.execute "drop document '#{name}'" rescue Sedna::Exception
    end
  end

  def test_transaction_should_raise_transaction_error_if_invalid_statement_caused_exception_but_it_was_rescued
    assert_raises Sedna::TransactionError do
      Sedna.connect @connection do |sedna|
        sedna.transaction do
          sedna.execute "FAILS" rescue Sedna::Exception
        end
      end
    end
  end
  
  def test_transaction_should_reraise_exceptions_from_inside_block
    Sedna.connect @connection do |sedna|
      assert_raises Exception do
        sedna.transaction do
          raise Exception
        end
      end
    end
  end

  def test_transaction_with_invalid_statements_should_cause_transaction_to_roll_back_once
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
end
