# Copyright 2019-2025 Wingify Software Pvt. Ltd.
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
require_relative '../lib/vwo/services/settings_file_manager'

class GetDummyResponse
  attr_reader :code, :body

  def initialize(code, body)
    @code = code
    @body = body
  end
end

class DummyErrorResponse
  def initialize
    raise 'Invalid sdk key'
  end
end

ACCOUNT_ID = 60_781
SDK_KEY = 'ea87170ad94079aa190bc7c9b85d26fb'

class SettingsFileManagerTest < Test::Unit::TestCase
  # Test that VWO::GetSettings.new fires off requests call with provided account_id and sdk_key.
  def test_get_settings_fires_request
    Net::HTTP.class_eval do
      def self.get_response(*_args)
        GetDummyResponse.new('200', 'dummy_setting_file')
      end
    end

    result = VWO::Services::SettingsFileManager.new(ACCOUNT_ID, SDK_KEY).get_settings_file
    assert_equal(result, 'dummy_setting_file')

    url = 'https://dev.visualwebsiteoptimizer.com/server-side/settings'
    params = {
      'a' => ACCOUNT_ID,
      'i' => SDK_KEY,
      'api-version' => 2,
      'r' => 0.05353966086631112,
      'platform' => 'server'
    }
    assert_send([Net::HTTP, :get, url, params])
  end

  # Test that VWO::GetSettings.new returns nil if status_code != 200.
  def test_get_settings_error_status_code
    Net::HTTP.class_eval do
      def self.get_response(*_args) # rubocop:todo Lint/DuplicateMethods
        GetDummyResponse.new('400', 'dummy_setting_file')
      end
    end
    result = VWO::Services::SettingsFileManager.new(ACCOUNT_ID, SDK_KEY).get_settings_file
    assert_nil(result)
  end

  def test_get_settings_with_exception
    Net::HTTP.class_eval do
      def self.get_response(*_args) # rubocop:todo Lint/DuplicateMethods
        DummyErrorResponse.new
      end
    end
    result = VWO::Services::SettingsFileManager.new(ACCOUNT_ID, SDK_KEY).get_settings_file
    assert_nil(result)
  end

  def test_account_id_0_return_none
    result = VWO::Services::SettingsFileManager.new(nil, SDK_KEY).get_settings_file
    assert_equal(result, '{}')
  end

  def test_empty_sdk_key_return_none
    result = VWO::Services::SettingsFileManager.new(ACCOUNT_ID, nil).get_settings_file
    assert_equal(result, '{}')
  end
end
