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
require_relative '../lib/vwo'
require 'logger'
require 'test/unit'
require 'mocha/test_unit'

MEG_SETTINGS_FILE = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/settings_meg.json')))

class MutuallyExclusiveTest < Test::Unit::TestCase
  def test_variation_return_as_whitelisting
    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))
    options = {
      variation_targeting_variables: {
        'chrome' => 'false'
      }
    }
    # called campaign satisfies the whitelisting
    variation = vwo_instance.activate(campaign_key, 'Ashley', options)
    variation_name = vwo_instance.get_variation_name(campaign_key, 'Ashley', options)
    is_goal_tracked = vwo_instance.track(campaign_key, 'Ashley', 'CUSTOM', options)[campaign_key]
    assert_equal(variation, 'Variation-1')
    assert_equal(variation_name, 'Variation-1')
    assert_equal(is_goal_tracked, true)
  end

  def test_null_variation_as_other_campaign_satisfies_whitelisting
    campaign_key = MEG_SETTINGS_FILE['campaigns'][3]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))
    options = {
      variation_targeting_variables: {
        'chrome' => 'false'
      }
    }

    variation = vwo_instance.activate(campaign_key, 'Ashley', options)
    is_goal_tracked = vwo_instance.track(campaign_key, 'Ashley', 'CUSTOM', options)
    variation_name = vwo_instance.get_variation_name(campaign_key, 'Ashley', options)
    assert_equal(nil, variation)
    assert_equal(nil, variation_name)
    assert_equal(false, is_goal_tracked[campaign_key])
  end

  def test_variation_for_called_campaign
    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, CustomUserStorage.new, true, JSON.generate(MEG_SETTINGS_FILE))

    variation = vwo_instance.activate(campaign_key, 'Ashley')
    is_goal_tracked = vwo_instance.track(campaign_key, 'Ashley', 'CUSTOM')[campaign_key]
    variation_name = vwo_instance.get_variation_name(campaign_key, 'Ashley')
    assert_equal('Control', variation)
    assert_equal('Control', variation_name)
    assert_equal(true, is_goal_tracked)
  end

  def test_null_variation_as_other_campaign_satisfies_storage
    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']
    variation_info = {
      'user_id' => 'Ashley',
      'name' => 'Control',
      'campaign_key' => campaign_key
    }
    user_storage = CustomUserStorage.new
    user_storage.set(variation_info)
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, user_storage, true, JSON.generate(MEG_SETTINGS_FILE))

    variation = vwo_instance.activate(campaign_key, 'Ashley')
    is_goal_tracked = vwo_instance.track(campaign_key, 'Ashley', 'CUSTOM')[campaign_key]
    variation_name = vwo_instance.get_variation_name(campaign_key, 'Ashley')
    assert_equal('Control', variation)
    assert_equal('Control', variation_name)
    assert_equal(true, is_goal_tracked)

    campaign_key = MEG_SETTINGS_FILE['campaigns'][3]['key']
    variation = vwo_instance.activate(campaign_key, 'Ashley')
    is_goal_tracked = vwo_instance.track(campaign_key, 'Ashley', 'CUSTOM')[campaign_key]
    variation_name = vwo_instance.get_variation_name(campaign_key, 'Ashley')
    assert_equal(nil, variation)
    assert_equal(nil, variation_name)
    assert_equal(false, is_goal_tracked)
    user_storage.remove('Ashley')
  end

  def test_variation_for_called_campaign_in_storage_and_other_campaign_satisfies_whitelisting
    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, CustomUserStorage.new, true, JSON.generate(MEG_SETTINGS_FILE))
    options = {
      variation_targeting_variables: {
        'browser' => 'chrome'
      }
    }

    segment_passed = {
      'or' => [
        'custom_variable' => {
          'browser' => 'chrome'
        }
      ]
    }

    variation = vwo_instance.activate(campaign_key, 'Ashley')
    assert_equal('Control', variation)
    vwo_instance.get_settings['campaigns'][1]['segments'] = segment_passed
    variation = vwo_instance.activate(campaign_key, 'Ashley', options)
    assert_equal('Control', variation)
  end

  def test_nil_variation_when_campaign_not_in_group
    campaign_key = MEG_SETTINGS_FILE['campaigns'][4]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))

    variation = vwo_instance.activate(campaign_key, 'Ashley')
    variation_name = vwo_instance.get_variation_name(campaign_key, 'Ashley')
    is_goal_tracked = vwo_instance.track(campaign_key, 'Ashley', 'CUSTOM')[campaign_key]
    assert_equal(nil, variation)
    assert_equal(nil, variation_name)
    assert_equal(false, is_goal_tracked)
  end

  def test_no_campaigns_satisfies_presegmentation
    campaign_key = MEG_SETTINGS_FILE['campaigns'][0]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))
    options = {
      customVariables: {
        'browser' => 'chrome'
      }
    }
    segment_passed = {
      'or' => [
        [
          custom_variable: {
            chrome: 'false'
          }
        ]
      ]
    }

    vwo_instance.get_settings['campaigns'][0]['segments'] = segment_passed
    vwo_instance.get_settings['campaigns'][1]['segments'] = segment_passed

    variation = vwo_instance.feature_enabled?(campaign_key, 'Ashley', options)
    variable_value = vwo_instance.get_feature_variable_value(campaign_key, 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(false, variation) # debug
    assert_equal(nil, variable_value) # debug

    # implementing the same condition with zero traffic percentage
    vwo_instance.get_settings['campaigns'][0]['percentTraffic'] = 0
    vwo_instance.get_settings['campaigns'][1]['percentTraffic'] = 0
    variation = vwo_instance.feature_enabled?(campaign_key, 'Ashley', options)
    variable_value = vwo_instance.get_feature_variable_value(campaign_key, 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(false, variation)
    assert_equal(nil, variable_value)
  end

  def test_called_campaign_not_satisfying_presegmentation
    campaign_key = MEG_SETTINGS_FILE['campaigns'][0]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))
    options = {
      customVariables: {
        'browser' => 'chrome'
      }
    }
    segment_failed = {
      'or' => [
        [
          custom_variable: {
            chrome: 'false'
          }
        ]
      ]
    }

    segment_passed = {
      'or' => [
        [
          custom_variable: {
            browser: 'chrome'
          }
        ]
      ]
    }

    vwo_instance.get_settings['campaigns'][0]['segments'] = segment_failed
    vwo_instance.get_settings['campaigns'][1]['segments'] = segment_passed
    variation = vwo_instance.feature_enabled?(campaign_key, 'Ashley', options)
    variable_value = vwo_instance.get_feature_variable_value(campaign_key, 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(false, variation)
    assert_equal(nil, variable_value)

    # implementing the same condition with different traffic percentage
    vwo_instance.get_settings['campaigns'][0]['percentTraffic'] = 0
    vwo_instance.get_settings['campaigns'][1]['percentTraffic'] = 100
    variation = vwo_instance.feature_enabled?(campaign_key, 'Ashley', options)
    variable_value = vwo_instance.get_feature_variable_value(campaign_key, 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(false, variation)
    assert_equal(nil, variable_value)
  end

  def test_only_called_campaign_satisfy_presegmentation
    campaign_key = MEG_SETTINGS_FILE['campaigns'][0]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))
    options = {
      custom_variables: {
        'browser' => 'chrome'
      }
    }
    segment_failed = {
      'or' => [
        'custom_variable' => {
          'chrome' => 'false'
        }
      ]
    }

    segment_passed = {
      'or' => [
        'custom_variable' => {
          'browser' => 'chrome'
        }
      ]
    }

    vwo_instance.get_settings['campaigns'][0]['segments'] = segment_passed
    vwo_instance.get_settings['campaigns'][1]['segments'] = segment_failed

    variation = vwo_instance.feature_enabled?(campaign_key, 'Ashley', options)
    variable_value = vwo_instance.get_feature_variable_value(campaign_key, 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(true, variation)
    assert_equal('Control string', variable_value)

    # #implementing the same condition with different traffic percentage
    vwo_instance.get_settings['campaigns'][0]['percentTraffic'] = 100
    vwo_instance.get_settings['campaigns'][1]['percentTraffic'] = 0
    variation = vwo_instance.feature_enabled?(campaign_key, 'Ashley', options)
    variable_value = vwo_instance.get_feature_variable_value(campaign_key, 'STRING_VARIABLE', 'Ashley', options)
    assert_equal(true, variation)
    assert_equal('Control string', variable_value)
  end

  def test_called_campaign_winner_campaign
    campaign_key = MEG_SETTINGS_FILE['campaigns'][0]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))

    # implementing the same condition with same traffic distribution
    vwo_instance.get_settings['campaigns'][0]['percentTraffic'] = 100
    vwo_instance.get_settings['campaigns'][1]['percentTraffic'] = 100
    variation = vwo_instance.feature_enabled?(campaign_key, 'Ashley')
    variable_value = vwo_instance.get_feature_variable_value(campaign_key, 'STRING_VARIABLE', 'Ashley')
    assert_equal(true, variation)
    assert_equal('Control string', variable_value)

    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']
    variation = vwo_instance.activate(campaign_key, 'Ashley')
    variation_name = vwo_instance.get_variation_name(campaign_key, 'Ashley')
    is_goal_tracked = vwo_instance.track(campaign_key, 'Ashley', 'CUSTOM')[campaign_key]
    assert_equal('Control', variation)
    assert_equal('Control', variation_name)
    assert_equal(true, is_goal_tracked)
  end

  def test_called_campaign_not_winner_campaign
    campaign_key = MEG_SETTINGS_FILE['campaigns'][0]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))

    # implementing the same condition with same traffic distribution
    vwo_instance.get_settings['campaigns'][0]['percentTraffic'] = 100
    vwo_instance.get_settings['campaigns'][1]['percentTraffic'] = 100
    variation = vwo_instance.feature_enabled?(campaign_key, 'lisa')
    assert_equal(false, variation)

    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']
    variation = vwo_instance.activate(campaign_key, 'lisa')
    assert_equal('Variation-1', variation)
  end

  def test_when_equal_traffic_among_eligible_campaigns
    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))

    # implementing the same condition with different traffic distribution
    vwo_instance.get_settings['campaigns'][2]['percentTraffic'] = 80
    vwo_instance.get_settings['campaigns'][3]['percentTraffic'] = 50
    variation = vwo_instance.activate(campaign_key, 'Ashley')
    assert_equal('Variation-1', variation)
  end

  def test_when_both_campaigns_new_to_user
    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))
    variation = vwo_instance.activate(campaign_key, 'Ashley')
    assert_equal('Control', variation)
    # campaigns are newly added to MEG.
    # user could be a part of any one of the campaign.
    campaign_key = MEG_SETTINGS_FILE['campaigns'][3]['key']
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, nil, true, JSON.generate(MEG_SETTINGS_FILE))
    variation = vwo_instance.activate(campaign_key, 'Ashley')
    assert_equal(nil, variation)
  end

  def test_when_user_already_part_of_campaign_and_new_campaign_added_to_group
    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']
    variation_info = {
      'user_id' => 'Ashley',
      'variation_name' => 'Control',
      'campaign_key' => campaign_key
    }
    user_storage = CustomUserStorage.new
    user_storage.set(variation_info)
    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, user_storage, true, JSON.generate(MEG_SETTINGS_FILE))
    # user is already a part of a campaign
    variation = vwo_instance.activate(campaign_key, 'Ashley')
    assert_equal('Control', variation)

    # new campaign is added to the group
    vwo_instance.get_settings['campaignGroups']['164'] = 2
    vwo_instance.get_settings['groups']['2']['campaigns'].push(164)
    campaign_key = MEG_SETTINGS_FILE['campaigns'][4]['key']
    variation = vwo_instance.activate(campaign_key, 'Ashley')
    assert_equal(nil, variation)
  end

  def test_when_viewed_campaign_removed_from_group
    campaign_key = MEG_SETTINGS_FILE['campaigns'][2]['key']

    variation_info = {
      'user_id' => 'Ashley',
      'variation_name' => 'Control',
      'campaign_key' => campaign_key
    }
    user_storage = CustomUserStorage.new
    user_storage.set(variation_info)

    vwo_instance = VWO.new(1, 'someuniquestuff1234567', nil, user_storage, true, JSON.generate(MEG_SETTINGS_FILE))

    # user is already a part of a campaign
    variation = vwo_instance.activate(campaign_key, 'Ashley')
    assert_equal('Control', variation)

    # old campaign is removed from the group
    vwo_instance.get_settings['groups']['2']['campaigns'] = [163]
    # since user has already seen that campaign, they will continue to become part of that campaign
    variation = vwo_instance.activate(campaign_key, 'Ashley')
    assert_equal('Control', variation)
  end
end
