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

require 'test/unit'
require 'json'
require_relative '../lib/vwo/core/bucketer'
require_relative '../lib/vwo/utils/campaign'

SETTINGS_FILE = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/settings.json')))

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
    result = @bucketer.user_part_of_campaign?(@user_id, nil)
    assert_equal(result, false)
  end

  def test_user_part_of_campaign_none_userid_passed
    result = @bucketer.user_part_of_campaign?(nil, @dummy_campaign)
    assert_equal(result, false)
  end

  def test_user_part_of_campaign_should_return_true
    user_id = 'Bob'
    # Bob, with above campaign settings, will get hashValue:2033809345 and
    # bucketValue:48. So, MUST be a part of campaign as per campaign
    # percentTraffic
    result = @bucketer.user_part_of_campaign?(user_id, @dummy_campaign)
    assert_equal(result, true)
  end

  def test_user_part_of_campaign_should_return_false
    user_id = 'Lucian'
    # Lucian, with above campaign settings, will get hashValue:2251780191
    # and bucketValue:53. So, must NOT be a part of campaign as per campaign
    # percentTraffic
    result = @bucketer.user_part_of_campaign?(user_id, @dummy_campaign)
    assert_equal(result, false)
  end

  def test_bucket_user_to_variation_none_campaign_passed
    result = @bucketer.bucket_user_to_variation(@user_id, nil)
    assert_equal(result, nil)
  end

  def test_bucket_user_to_variation_none_userid_passed
    result = @bucketer.bucket_user_to_variation(nil, @dummy_campaign)
    assert_equal(result, nil)
  end

  def test_bucket_user_to_variation_return_control
    user_id = 'Sarah'
    # Sarah, with above campaign settings, will get hashValue:69650962 and
    # bucketValue:326. So, MUST be a part of Control, as per campaign
    # settings
    result = @bucketer.bucket_user_to_variation(user_id, @dummy_campaign)
    assert_equal(result['name'], 'Control')
  end

  def test_bucket_user_to_variation_return_varitaion_1
    user_id = 'Varun'
    # Varun, with above campaign settings, will get hashValue:69650962 and
    # bucketValue:326. So, MUST be a part of Variation-1, as per campaign
    # settings
    result = @bucketer.bucket_user_to_variation(user_id, @dummy_campaign)
    assert_equal(result['name'], 'Variation-1')
  end

  def test_get_variation_return_none
    campaign = ::SETTINGS_FILE['AB_T_50_W_50_50']['campaigns'][0]
    set_variation_allocation(campaign)
    result = @bucketer.send(:get_variation, campaign['variations'], 10001)
    assert_equal(result, nil)
  end
end
