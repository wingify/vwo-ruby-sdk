# Copyright 2019 Wingify Software Pvt. Ltd.
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
require_relative '../lib/vwo/user_storage'

class UserStorageTest < Test::Unit::TestCase
  def test_class_initialization
    assert_not_nil(VWO::UserStorage)
  end

  def test_check_get_is_present
    user_storage = VWO::UserStorage.new
    assert_nil(user_storage.get('123', 'campaign_key'))
  end

  def test_check_save_is_present
    user_storage = VWO::UserStorage.new
    map = {
      'user_id': '123',
      'campaign_key': 'campaign_key',
      'variation_name': 'Variation-1'
    }
    assert_nil(user_storage.set(map))
  end
end
