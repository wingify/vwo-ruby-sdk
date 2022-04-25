# Copyright 2019-2022 Wingify Software Pvt. Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'test/unit'
require 'json'
require_relative '../lib/vwo/services/event_dispatcher'
require 'net/http'

class DummyResponse
  def initialize(code)
    @code = code
  end

  attr_reader :code
end

class EventDispatcherTest < Test::Unit::TestCase
  def setup
    @dispatcher = VWO::Services::EventDispatcher.new
  end

  # Test that dispatch event fires off requests call with provided URL and params.
  def test_dispatch_fires_request
    Net::HTTP.class_eval do
      def self.get_response(*_args)
        DummyResponse.new('200')
      end
    end

    properties = {
      'env' => 'dummyKey',
      'combination' => 1,
      'url' => 'https://dev.visualwebsiteoptimizer.com/server-side/track-user',
      'ed' => '{"p": "server"}',
      'random' => 0.7382938446947298,
      'ap' => 'server',
      'u' => '09CD6107E42B51F9BFC3DD97EA900990',
      'experiment_id' => 229,
      'sId' => 1_565_949_670,
      'sdk-v' => '1.0.2',
      'sdk' => 'python',
      'account_id' => 60_781
    }

    result = @dispatcher.dispatch(properties, {}, 'end_point')
    assert_equal(result, true)

    properties['url']
    properties['url'] = nil
    assert_send([Net::HTTP, :get_response, properties])
  end

  # Test that dispatch returns false if status_code != 200
  def test_dispatch_error_status_code
    Net::HTTP.class_eval do
      def self.get_response(*_args) # rubocop:todo Lint/DuplicateMethods
        DummyResponse.new('503')
      end
    end

    properties = {
      'env' => 'dummyKey',
      'combination' => 1,
      'url' => 'https://dev.visualwebsiteoptimizer.com/server-side/track-user', # noqa: E501
      'ed' => '{"p": "server"}',
      'random' => 0.7382938446947298,
      'ap' => 'server',
      'u' => '09CD6107E42B51F9BFC3DD97EA900990',
      'experiment_id' => 229,
      'sId' => 1_565_949_670,
      'sdk-v' => '1.0.2',
      'sdk' => 'python',
      'account_id' => 60_781
    }

    result = @dispatcher.dispatch(properties, {}, 'end_point')
    assert_equal(result, false)
  end

  # Test that dispatch returns False if exception occurs.
  def test_dispatch_with_exception
    Net::HTTP.class_eval do
      def self.get_response(*_args) # rubocop:todo Lint/DuplicateMethods
        raise
      end
    end

    properties = {
      'env' => 'dummyKey',
      'combination' => 1,
      'url' => 'https://dev.visualwebsiteoptimizer.com/server-side/track-user',
      'ed' => '{"p": "server"}',
      'random' => 0.7382938446947298,
      'ap' => 'server',
      'u' => '09CD6107E42B51F9BFC3DD97EA900990',
      'experiment_id' => 229,
      'sId' => 1_565_949_670,
      'sdk-v' => '1.0.2',
      'sdk' => 'python',
      'account_id' => 60_781
    }

    result = @dispatcher.dispatch(properties, {}, 'end_point')
    assert_equal(result, false)
  end
end
