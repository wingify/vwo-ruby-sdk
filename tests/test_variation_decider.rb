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
require_relative '../lib/vwo/core/variation_decider'
require_relative '../lib/vwo/user_storage'
require_relative '../lib/vwo/utils/campaign'

VWO_SETTINGS_FILE = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/settings.json')))

class CustomUserStorage < VWO::UserStorage
  @@client_db = {}

  def get(user_id, campaign_key)
    @@client_db[user_id][campaign_key]
  end

  def set(user_storage_obj)
    @@client_db[user_storage_obj['user_id']] = {}
    @@client_db[user_storage_obj['user_id']][user_storage_obj['campaign_key']] = user_storage_obj
  end

  def remove(user_id)
    @@client_db[user_id] = nil
  end
end

class BrokenUserStorage
  @@client_db = {}

  def get(user_id, campaign_key)
    @@client_db[user_id][campaign_key]
  end

  def set(_user_storage_obj)
    raise
  end
end

class VariationDeciderTest < Test::Unit::TestCase
  include VWO::Utils::Campaign

  def setup
    @user_id = rand.to_s
    @settings_file = VWO_SETTINGS_FILE['DUMMY_SETTINGS_FILE']
    @dummy_campaign = @settings_file['campaigns'][0]
    @campaign_key = @dummy_campaign['key']
    set_variation_allocation(@dummy_campaign)
    @variation_decider = VWO::Core::VariationDecider.new(@settings_file)
  end

  def test_init_with_valid_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, CustomUserStorage.new)
    assert_equal(variation_decider.user_storage_service.class, CustomUserStorage)
    assert_equal(variation_decider.user_storage_service.is_a?(VWO::UserStorage), true)
  end

  def test_init_with_our_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, VWO::UserStorage.new)
    assert_equal(variation_decider.user_storage_service.class, VWO::UserStorage)
  end

  def test_get_variation_allotted_none_campaign_passed
    variation = @variation_decider.get_variation_allotted(@user_id, nil)
    assert_nil(variation)
  end

  def test_get_variation_allotted_none_userid_passed
    variation = @variation_decider.get_variation_allotted(nil, @dummy_campaign)
    assert_nil(variation)
  end

  def test_get_variation_allotted_should_return_true
    user_id = 'Allie'
    # Allie, with above campaign settings, will get hashValue:362121553
    # and bucketValue:1688. So, MUST be a part of campaign as per campaign
    # percentTraffic
    variation = @variation_decider.get_variation_allotted(user_id, @dummy_campaign)
    assert_equal(variation['id'], '1')
    assert_equal(variation['name'], 'Control')
  end

  def test_get_variation_allotted_should_return_false
    user_id = 'Lucian'
    # Lucian, with above campaign settings, will get hashValue:2251780191
    # and bucketValue:53. So, MUST be a part of campaign as per campaign
    # percentTraffic
    variation = @variation_decider.get_variation_allotted(user_id, @dummy_campaign)
    assert_nil(variation)
  end

  def test_get_variation_of_campaign_for_user_none_userid_passed
    variation =
      @variation_decider.get_variation_of_campaign_for_user(nil, @dummy_campaign)
    assert_nil(variation)
  end

  def test_get_variation_of_campaign_for_user_none_campaing_passed
    variation =
      @variation_decider.get_variation_of_campaign_for_user(@user_id, nil)
    assert_nil(variation)
  end

  def test_get_variation_of_campaign_for_user_should_return_control
    user_id = 'Sarah'
    # Sarah, with above campaign settings, will get hashValue:69650962
    # and bucketValue:326. So, MUST be a part of Control, as per campaign
    # settings
    variation =
      @variation_decider.get_variation_of_campaign_for_user(user_id, @dummy_campaign)
    assert_equal(variation['name'], 'Control')
  end

  def test_get_variation_of_campaign_for_user_should_return_variation
    user_id = 'Varun'
    # Varun, with above campaign settings, will get hashValue:2025462540
    # and bucketValue:9433. So, MUST be a part of Variation, as per campaign
    # settings
    variation = @variation_decider.get_variation_of_campaign_for_user(user_id, @dummy_campaign)
    assert_equal(variation['name'], 'Variation-1')
  end

  def test_get_none_userid_passed
    variation = @variation_decider.get_variation(nil, @dummy_campaign, '', @campaign_key)
    assert_nil(variation)
  end

  def test_get_none_campaign_passed
    variation = @variation_decider.get_variation(@user_id, nil, '', @campaign_key)
    assert_nil(variation)
  end

  def test_get_none_campaing_key_passed
    user_id = 'Sarah'
    variation = @variation_decider.get_variation(user_id, @dummy_campaign, '', @campaign_key)
    assert_equal(variation['id'], '1')
    assert_equal(variation['name'], 'Control')
  end

  def test_get_with_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, CustomUserStorage.new)

    # First let variation_decider compute vairation, and store
    user_id = 'Sarah'
    variation = variation_decider.get_variation(user_id, @dummy_campaign, '', @campaign_key)
    assert_equal(variation['id'], '1')
    assert_equal(variation['name'], 'Control')

    # Now check whether the variation_decider is able to retrieve
    # variation for user_storage, no campaign is required
    # for this.
    variation = variation_decider.get_variation(user_id, @dummy_campaign, '', @campaign_key)
    assert_equal(variation['id'], '1')
    assert_equal(variation['name'], 'Control')
  end

  def test_get_with_broken_save_in_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, BrokenUserStorage.new)

    user_id = 'Sarah'
    variation = variation_decider.get_variation(user_id, @dummy_campaign, '', @campaign_key)
    assert_equal(variation['id'], '1')
    assert_equal(variation['name'], 'Control')
  end

  def test_get_with_broken_get_in_user_storage
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, CustomUserStorage.new)

    user_id = 'Sarah'
    variation = variation_decider.get_variation(user_id, @dummy_campaign, '', @campaign_key)
    assert_equal(variation['id'], '1')
    assert_equal(variation['name'], 'Control')

    variation = variation_decider.get_variation(user_id, @dummy_campaign, '', @campaign_key)
    assert_equal(variation['id'], '1')
    assert_equal(variation['name'], 'Control')
  end

  def test_get_with_user_storage_but_no_stored_variation
    custom_user_storage = CustomUserStorage.new
    variation_decider = VWO::Core::VariationDecider.new(@settings_file, custom_user_storage)

    # First let variation_decider compute vairation, and store
    user_id = 'Sarah'
    variation = variation_decider.get_variation(user_id, @dummy_campaign, '', @campaign_key)
    assert_equal(variation['id'], '1')
    assert_equal(variation['name'], 'Control')

    # Now delete the stored variation from campaign_bucket_map
    custom_user_storage.remove(user_id)
    # Now the variation_decider is not able to retrieve
    # variation from user_storage.
    variation = variation_decider.get_variation(user_id, @dummy_campaign, '', @campaign_key)
    assert_equal(variation['id'], '1')
    assert_equal(variation['name'], 'Control')
  end

  def test_variation_data_for_real_time_pre_segmentation
    user_id = 'Sarah'
    settings_file = VWO_SETTINGS_FILE['REAL_TIME_PRE_SEGEMENTATION']
    campaign = settings_file['campaigns'][0]
    campaign_key = campaign['key']
    set_variation_allocation(campaign)
    variation_decider = VWO::Core::VariationDecider.new(settings_file)
    variation = variation_decider.get_variation(user_id, campaign, 'test_cases', campaign_key, { a: 123 })
    assert_equal(variation['name'], 'Control')

    storage = CustomUserStorage.new
    new_campaign_user_mapping = {}
    new_campaign_user_mapping['campaign_key'] = campaign_key
    new_campaign_user_mapping['user_id'] = user_id
    new_campaign_user_mapping['variation_name'] = 'Variation-1'
    # setting variation-1 in storage then we get variation-1 when isAlwaysCheckSegment flag not there
    storage.set(new_campaign_user_mapping)
    campaign.delete('isAlwaysCheckSegment')
    variation_decider = VWO::Core::VariationDecider.new(settings_file, storage)
    assert_equal(storage.get(user_id, campaign_key)['variation_name'], new_campaign_user_mapping['variation_name'])
    variation = variation_decider.get_variation(user_id, campaign, 'test_cases', campaign_key, { a: 123 })
    assert_equal(variation['name'], new_campaign_user_mapping['variation_name'])

    # variation-1 is there in storage but we get Control when isAlwaysCheckSegment flag is set
    campaign['isAlwaysCheckSegment'] = true
    variation = variation_decider.get_variation(user_id, campaign, 'test_cases', campaign_key, { a: 123 })
    assert_equal(variation['name'], 'Control')
  end
end
