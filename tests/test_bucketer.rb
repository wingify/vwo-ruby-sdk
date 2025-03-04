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
require_relative '../lib/vwo/core/bucketer'
require_relative '../lib/vwo/utils/campaign'
require_relative 'test_util'
require_relative '../lib/vwo/utils/get_account_flags'

SETTINGS_FILE_1 = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/settings.json')))
SETTINGS_FILE_2 = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/settings-bucketing.json')))
USER_EXPECTATIONS = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/user_expectations.json')))
class BucketerTest < Test::Unit::TestCase
  include VWO::Utils::Campaign

  def setup
    @user_id = rand.to_s
    @dummy_campaign = {
      'goals' => [
        {
          'identifier' => 'GOAL_NEW',
          'id' => 203,
          'type' => 'CUSTOM_GOAL'
        }
      ],
      'variations' => [
        {
          'id' => '1',
          'name' => 'Control',
          'weight' => 40
        },
        {
          'id' => '2',
          'name' => 'Variation-1',
          'weight' => 60
        }
      ],
      'id' => 22,
      'percentTraffic' => 50,
      'key' => 'UNIQUE_KEY',
      'status' => 'RUNNING',
      'type' => 'VISUAL_AB'
    }
    set_variation_allocation(@dummy_campaign)
    @bucketer = VWO::Core::Bucketer.new
  end

  def test_user_part_of_campaign_none_campaign_passed
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    result = @bucketer.user_part_of_campaign?(@user_id, nil)
    assert_equal(result, false)
  end

  def test_user_part_of_campaign_none_userid_passed
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    result = @bucketer.user_part_of_campaign?(nil, @dummy_campaign)
    assert_equal(result, false)
  end

  def test_user_part_of_campaign_should_return_true
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    user_id = 'Bob'
    # Bob, with above campaign settings, will get hashValue:2033809345 and
    # bucketValue:48. So, MUST be a part of campaign as per campaign
    # percentTraffic
    result = @bucketer.user_part_of_campaign?(user_id, @dummy_campaign)
    assert_equal(result, true)
  end

  def test_user_part_of_campaign_should_return_false
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    user_id = 'Lucian'
    # Lucian, with above campaign settings, will get hashValue:2251780191
    # and bucketValue:53. So, must NOT be a part of campaign as per campaign
    # percentTraffic
    result = @bucketer.user_part_of_campaign?(user_id, @dummy_campaign)
    assert_equal(result, false)
  end

  def test_bucket_user_to_variation_none_campaign_passed
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    result = @bucketer.bucket_user_to_variation(@user_id, nil)
    assert_equal(result, nil)
  end

  def test_bucket_user_to_variation_none_userid_passed
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    result = @bucketer.bucket_user_to_variation(nil, @dummy_campaign)
    assert_equal(result, nil)
  end

  def test_bucket_user_to_variation_return_control
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    user_id = 'Sarah'
    # Sarah, with above campaign settings, will get hashValue:69650962 and
    # bucketValue:326. So, MUST be a part of Control, as per campaign
    # settings
    result = @bucketer.bucket_user_to_variation(user_id, @dummy_campaign)
    assert_equal(result['name'], 'Control')
  end

  def test_bucket_user_to_variation_return_varitaion1
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    user_id = 'Varun'
    # Varun, with above campaign settings, will get hashValue:69650962 and
    # bucketValue:326. So, MUST be a part of Variation-1, as per campaign
    # settings
    result = @bucketer.bucket_user_to_variation(user_id, @dummy_campaign)
    assert_equal(result['name'], 'Variation-1')
  end

  def test_get_variation_return_none
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    campaign = ::SETTINGS_FILE_1['AB_T_50_W_50_50']['campaigns'][0]
    set_variation_allocation(campaign)
    result = @bucketer.send(:get_variation, campaign['variations'], 10_001)
    assert_equal(result, nil)
  end

  def test_get_bucket_value_for_user_25_someonemailcom
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    campaign = { 'id' => 1, 'isBucketingSeedEnabled' => true }
    bucket_value = @bucketer.get_bucket_value_for_user('someone@mail.com', campaign)
    assert_equal(bucket_value, 25)

    campaign['isBucketingSeedEnabled'] = false
    bucket_value = @bucketer.get_bucket_value_for_user('someone@mail.com', campaign)
    assert_equal(bucket_value, 64)
  end

  def test_get_bucket_value_for_user1111111111111111
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    campaign = { 'id' => 1, 'isBucketingSeedEnabled' => true }
    bucket_value = @bucketer.get_bucket_value_for_user('1111111111111111', campaign)
    assert_equal(bucket_value, 82)

    campaign['isBucketingSeedEnabled'] = false
    bucket_value = @bucketer.get_bucket_value_for_user('1111111111111111', campaign)
    assert_equal(bucket_value, 50)
  end

  def test_get_bucket_value_for_user_25_someonemailcom_when_bucketing_seed_passed_as_symbol
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    campaign = { 'id' => 1, isBucketingSeedEnabled: true }
    bucket_value = @bucketer.get_bucket_value_for_user('someone@mail.com', campaign)
    assert_equal(bucket_value, 64)

    campaign[:isBucketingSeedEnabled] = false
    bucket_value = @bucketer.get_bucket_value_for_user('someone@mail.com', campaign)
    assert_equal(bucket_value, 64)
  end

  def test_get_bucket_value_for_user_1111111111111111_when_bucketing_seed_passed_as_symbol
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    campaign = { 'id' => 1, isBucketingSeedEnabled: true }
    bucket_value = @bucketer.get_bucket_value_for_user('1111111111111111', campaign)
    assert_equal(bucket_value, 50)

    campaign[:isBucketingSeedEnabled] = false
    bucket_value = @bucketer.get_bucket_value_for_user('1111111111111111', campaign)
    assert_equal(bucket_value, 50)
  end

  def test_should_return_variation_with_old_bucketing_logic_when_seed_not_enabled
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    campaign = SETTINGS_FILE_2['settingsWithoutSeedAndWithoutisOB']['campaigns'][0]
    set_variation_allocation(campaign)

    TestUtil.get_users.each_with_index do |user_id, index|
      result = @bucketer.bucket_user_to_variation(user_id, campaign)
      assert_equal(result['name'], USER_EXPECTATIONS['BUCKET_ALGO_WITHOUT_SEED'][index]['variation'])
    end
  end

  def test_should_return_variation_with_old_bucketing_logic_when_seed_enabled
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => false})
    campaign = SETTINGS_FILE_2['settingsWithSeedAndWithoutisOB']['campaigns'][0]
    set_variation_allocation(campaign)
  
    TestUtil.get_users.each_with_index do |user_id, index|
      result = @bucketer.bucket_user_to_variation(user_id, campaign)
      assert_equal(result['name'], USER_EXPECTATIONS['BUCKET_ALGO_WITH_SEED'][index]['variation'])
    end
  end
  
  def test_should_return_variation_with_seed_isNB_true_isOB_true
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => true})
    campaign = SETTINGS_FILE_2['settingsWithisNBAndWithisOB']['campaigns'][0]
    set_variation_allocation(campaign)
  
    TestUtil.get_users.each_with_index do |user_id, index|
      result = @bucketer.bucket_user_to_variation(user_id, campaign)
      assert_equal(result['name'], USER_EXPECTATIONS['BUCKET_ALGO_WITH_SEED_WITH_isNB_WITH_isOB'][index]['variation'])
    end
  end
  
  def test_should_return_variation_with_isNB_true_isOB_not_present_with_new_logic
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => true})
    campaign = SETTINGS_FILE_2['settingsWithisNBAndWithoutisOB']['campaigns'][0]
    set_variation_allocation(campaign)
  
    TestUtil.get_users.each_with_index do |user_id, index|
      result = @bucketer.bucket_user_to_variation(user_id, campaign)
      assert_equal(result['name'], USER_EXPECTATIONS['BUCKET_ALGO_WITH_SEED_WITH_isNB_WITHOUT_isOB'][index]['variation'])
    end
  end
  
  def test_should_return_variation_with_isNB_true_isOB_not_present_without_seed_flag
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => true})
    campaign = SETTINGS_FILE_2['settingsWithisNBAndWithoutisOBAndWithoutSeedFlag']['campaigns'][0]
    set_variation_allocation(campaign)
  
    TestUtil.get_users.each_with_index do |user_id, index|
      result = @bucketer.bucket_user_to_variation(user_id, campaign)
      assert_equal(result['name'], USER_EXPECTATIONS['BUCKET_ALGO_WITH_SEED_WITH_isNB_WITHOUT_isOB'][index]['variation'])
    end
  end

  def test_should_return_same_variation_for_multiple_campaigns_with_isNB_true
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => true})
    campaign_list = [
      SETTINGS_FILE_2['settingsWithisNBAndWithoutisOB']['campaigns'][0],
      SETTINGS_FILE_2['settingsWithisNBAndWithoutisOB']['campaigns'][1],
      SETTINGS_FILE_2['settingsWithisNBAndWithoutisOB']['campaigns'][2]
    ]
  
    3.times do |i|
      set_variation_allocation(SETTINGS_FILE_2['settingsWithisNBAndWithoutisOB']['campaigns'][i])
      result = @bucketer.bucket_user_to_variation('Ashley', campaign_list[i])
      assert_equal(result['name'], 'Control')
    end
  end
  
  def test_should_return_different_variation_for_multiple_campaigns_with_isNBv2_true
    VWO::Utils::GetAccountFlags.get_instance.set_settings({'isNB' => true, 'isNBv2' => true, 'accountId' => SETTINGS_FILE_2['settingsWithisNBAndisNBv2']['accountId']})
  
    3.times do |i|
      set_variation_allocation(SETTINGS_FILE_2['settingsWithisNBAndisNBv2']['campaigns'][i])
      result = @bucketer.bucket_user_to_variation(
        USER_EXPECTATIONS['SETTINGS_WITH_ISNB_WITH_ISNBv2'][i]['user'],
        SETTINGS_FILE_2['settingsWithisNBAndisNBv2']['campaigns'][i]
      )
      assert_equal(result['name'], USER_EXPECTATIONS['SETTINGS_WITH_ISNB_WITH_ISNBv2'][i]['variation'])
    end
  end
  
end