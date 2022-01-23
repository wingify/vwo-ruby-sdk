# Copyright 2019-2021 Wingify Software Pvt. Ltd.
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
require 'test/unit'

class UtilityTest < Test::Unit::TestCase
  include VWO::Utils::Utility

  def test_convert_to_symbol_hash_with_valid_hash
    hashObject = { 'name': 'CUSTOM' }
    expectation = { name: 'CUSTOM' }
    result = convert_to_symbol_hash(hashObject)
    assert_equal(expectation, result)
  end

  def test_convert_to_symbol_hash_with_empty_hash
    hashObject = {}
    expectation = {}
    result = convert_to_symbol_hash(hashObject)
    assert_equal(expectation, result)
  end

  def test_convert_to_symbol_hash_with_nil
    hashObject = nil
    expectation = {}
    result = convert_to_symbol_hash(hashObject)
    assert_equal(expectation, result)
  end

end
