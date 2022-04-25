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

require 'json'
require_relative '../lib/vwo/utils/utility'
require_relative '../lib/vwo/utils/data_location_manager'
require_relative '../lib/vwo/constants'
require 'test/unit'

class UtilityTest < Test::Unit::TestCase
  include VWO::Utils::Utility
  include VWO::CONSTANTS

  def test_convert_to_symbol_hash_with_valid_hash
    hash_object = { 'name': 'CUSTOM' }
    expectation = { name: 'CUSTOM' }
    result = convert_to_symbol_hash(hash_object)
    assert_equal(expectation, result)
  end

  def test_convert_to_symbol_hash_with_empty_hash
    hash_object = {}
    expectation = {}
    result = convert_to_symbol_hash(hash_object)
    assert_equal(expectation, result)
  end

  def test_convert_to_symbol_hash_with_nil
    hash_object = nil
    expectation = {}
    result = convert_to_symbol_hash(hash_object)
    assert_equal(expectation, result)
  end

  def test_get_url_without
    settings = {}
    DataLocationManager.get_instance.set_settings(settings)
    assert_equal(ENDPOINTS::BASE_URL, get_url(''))
  end

  def test_get_url_with_data
    settings = { 'collectionPrefix' => 'eu' }
    DataLocationManager.get_instance.set_settings(settings)
    assert_equal("#{ENDPOINTS::BASE_URL}/eu", get_url(''))
  end
end
