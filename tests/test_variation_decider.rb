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
require 'json'
require_relative '../lib/vwo/core/variation_decider'
require_relative '../lib/vwo/user_storage'
require_relative '../lib/vwo/utils/campaign'

SETTINGS_FILE = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/settings.json')))

class UserStorage
  def save(_user_id); end

  def get(_user_storage_obj); end
end

class CustomUserStorage
  @@client_db = {}

  def get(user_id)
    @@client_db[user_id]
  end

  def save(user_storage_obj)
    @@client_db[user_storage_obj[:userId]] = user_storage_obj
  end

  def remove(user_id)
    @@client_db[user_id] = nil
  end
end

class BrokenUserStorage
  @@client_db = {}

  def get(user_id)
    return @@client_db.get(user_id)
  end

  def save(_user_storage_obj)
    raise
  end
end

class VariationDeciderTest < Test::Unit::TestCase
  include VWO::Utils::Campaign

  def setup
    @user_id = rand.to_s
    @settings_file = SETTINGS_FILE['7']
    @dummy_campaign = @settings_file['campaigns'][0]
    @campaign_key = @dummy_campaign['key']
    set_variation_allocation(@dummy_campaign)
    @variation_decider = VWO::Core::VariationDecider.new(@settings_file)
  end

  def test_init_with_valid_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, UserStorage.new)
    assert_equal(variation_decider.user_storage_service.class, UserStorage)
  end

  def test_init_with_our_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, VWO::UserStorage.new)
    assert_equal(variation_decider.user_storage_service.class, VWO::UserStorage)
  end

  def test_get_variation_allotted_none_campaign_passed
    variation_id, variation_name = @variation_decider.get_variation_allotted(@user_id, nil)
    assert_nil(variation_id)
    assert_nil(variation_name)
  end

  def test_get_variation_allotted_none_userid_passed
    variation_id, variation_name = @variation_decider.get_variation_allotted(nil, @dummy_campaign)
    assert_nil(variation_id)
    assert_nil(variation_name)
  end

  def test_get_variation_allotted_should_return_true
    user_id = 'Allie'
    # Allie, with above campaign settings, will get hashValue:362121553
    # and bucketValue:1688. So, MUST be a part of campaign as per campaign
    # percentTraffic
    variation_id, variation_name = @variation_decider.get_variation_allotted(user_id, @dummy_campaign)
    assert_equal(variation_id, '1')
    assert_equal(variation_name, 'Control')
  end

  def test_get_variation_allotted_should_return_false
    user_id = 'Lucian'
    # Lucian, with above campaign settings, will get hashValue:2251780191
    # and bucketValue:53. So, MUST be a part of campaign as per campaign
    # percentTraffic
    variation_id, variation_name = @variation_decider.get_variation_allotted(user_id, @dummy_campaign)
    assert_nil(variation_id)
    assert_nil(variation_name)
  end

  def test_get_variation_of_campaign_for_user_none_userid_passed
    variation_id, variation_name =
      @variation_decider.get_variation_of_campaign_for_user(nil, @dummy_campaign)
    assert_nil(variation_id)
    assert_nil(variation_name)
  end

  def test_get_variation_of_campaign_for_user_none_campaing_passed
    variation_id, variation_name =
      @variation_decider.get_variation_of_campaign_for_user(@user_id, nil)
    assert_nil(variation_id)
    assert_nil(variation_name)
  end

  def test_get_variation_of_campaign_for_user_should_return_Control
    user_id = 'Sarah'
    # Sarah, with above campaign settings, will get hashValue:69650962
    # and bucketValue:326. So, MUST be a part of Control, as per campaign
    # settings
    _variation_id, variation_name =
      @variation_decider.get_variation_of_campaign_for_user(user_id, @dummy_campaign)
    assert_equal(variation_name, 'Control')
  end

  def test_get_variation_of_campaign_for_user_should_return_Variation
    user_id = 'Varun'
    # Varun, with above campaign settings, will get hashValue:2025462540
    # and bucketValue:9433. So, MUST be a part of Variation, as per campaign
    # settings
    _variation_id, variation_name = @variation_decider.get_variation_of_campaign_for_user(user_id, @dummy_campaign)
    assert_equal(variation_name, 'Variation-1')
  end

  def test_get_none_userid_passed
    variation_id, variation_name = @variation_decider.get_variation(nil, @dummy_campaign)
    assert_nil(variation_id)
    assert_nil(variation_name)
  end

  def test_get_none_campaign_passed
    variation_id, variation_name = @variation_decider.get_variation(@user_id, nil)
    assert_nil(variation_id)
    assert_nil(variation_name)
  end

  def test_get_none_campaing_key_passed
    user_id = 'Sarah'
    variation_id, variation_name = @variation_decider.get_variation(user_id, @dummy_campaign)
    assert_equal(variation_id, '1')
    assert_equal(variation_name, 'Control')
  end

  def test_get_with_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, CustomUserStorage.new)

    # First let variation_decider compute vairation, and store
    user_id = 'Sarah'
    variation_id, variation_name = variation_decider.get_variation(user_id, @dummy_campaign)
    assert_equal(variation_id, '1')
    assert_equal(variation_name, 'Control')

    # Now check whether the variation_decider is able to retrieve
    # variation for user_storage, no campaign is required
    # for this.
    variation_id, variation_name = variation_decider.get_variation(user_id, @dummy_campaign)
    assert_equal(variation_id, '1')
    assert_equal(variation_name, 'Control')
  end

  def test_get_with_broken_save_in_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, BrokenUserStorage.new)

    user_id = 'Sarah'
    variation_id, variation_name = variation_decider.get_variation(user_id, @dummy_campaign)
    assert_equal(variation_id, '1')
    assert_equal(variation_name, 'Control')
  end

  def test_get_with_broken_get_in_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, UserStorage.new)

    user_id = 'Sarah'
    variation_id, variation_name = variation_decider.get_variation(user_id, @dummy_campaign)
    assert_equal(variation_id, '1')
    assert_equal(variation_name, 'Control')

    variation_id, variation_name = variation_decider.get_variation(user_id, @dummy_campaign)
    assert_equal(variation_id, '1')
    assert_equal(variation_name, 'Control')
  end

  def test_get_with_user_storage_but_no_stored_variation
    custom_user_storage = CustomUserStorage.new
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, custom_user_storage)

    # First let variation_decider compute vairation, and store
    user_id = 'Sarah'
    variation_id, variation_name = variation_decider.get_variation(user_id, @dummy_campaign)
    assert_equal(variation_id, '1')
    assert_equal(variation_name, 'Control')

    # Now delete the stored variaion from campaign_bucket_map
    custom_user_storage.remove(user_id)
    # Now the variation_decider is not able to retrieve
    # variation from user_storage.
    variation_id, variation_name = variation_decider.get_variation(user_id, @dummy_campaign)
    assert_equal(variation_id, '1')
    assert_equal(variation_name, 'Control')
  end
end
