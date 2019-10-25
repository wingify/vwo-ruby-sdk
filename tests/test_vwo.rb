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
require_relative '../lib/vwo'

# from .data.settings_files import SETTINGS_FILES
# from .data.settings_file_and_user_expectations import USER_EXPECTATIONS

DEV_TEST = 'DEV_TEST_'
SETTINGS_FILE = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/settings.json')))
USER_EXPECTATIONS = JSON.load(File.open(File.join(File.dirname(__FILE__), 'data/user_expectations.json')))

class VWOTest < Test::Unit::TestCase

  def set_up(config_variant = 1)
    @user_id = rand.to_s
    @vwo = VWO.new(60781, 'ea87170ad94079aa190bc7c9b85d26fb', nil, nil, true, JSON.generate(SETTINGS_FILE[config_variant.to_s]))
    @campaign_key = "#{DEV_TEST}#{config_variant}"
    @goal_identifier = SETTINGS_FILE[config_variant.to_s]['campaigns'][0]['goals'][0]['identifier'] if SETTINGS_FILE[config_variant.to_s].keys.count > 0
  end

  # Test initialization
  def test_init_vwo_with_invalid_settings_file
    set_up(0)
    assert_equal(@vwo.is_instance_valid, false)
  end

  # Test get_variation
  def test_get_variation_invalid_params
    set_up()
    assert_equal(@vwo.get_variation_name(123, 456), nil)
  end

  def test_get_variation_invalid_config
    set_up(0)
    assert_equal(@vwo.get_variation_name(@user_id, 'some_campaign'), nil)
  end

  def test_get_variation_with_no_campaign_key_found
    set_up(1)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name('NO_SUCH_CAMPAIGN_KEY', test['user']), nil)
    end
  end

  def test_get_variation_against_campaign_traffic_50_and_split_50_50
    set_up(1)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end


  def test_get_variation_against_campaign_traffic_100_and_split_50_50
    set_up(2)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_20_80
    set_up(3)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_20_and_split_10_90
    set_up(4)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_0_100
    set_up(5)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_get_variation_against_campaign_traffic_100_and_split_33_x3
    set_up(6)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.get_variation_name(@campaign_key, test['user']), test['variation'])
    end
  end

  # Test activate
  def test_activate_invalid_params
    set_up()
    assert_equal(@vwo.activate(123, 456), nil)
  end

  def test_activate_invalid_config
    set_up(0)
    assert_equal(@vwo.activate(@user_id, 'some_campaign'), nil)
  end

  def test_activate_with_no_campaign_key_found
    set_up(1)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate('NO_SUCH_CAMPAIGN_KEY', test['user']), nil)
    end
  end

  def test_activate_against_campaign_traffic_50_and_split_50_50
    set_up(1)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_50_50
    set_up(2)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_20_80
    set_up(3)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_20_and_split_10_90
    set_up(4)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_0_100
    set_up(5)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key, test['user']), test['variation'])
    end
  end

  def test_activate_against_campaign_traffic_100_and_split_33_x3
    set_up(6)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.activate(@campaign_key,test['user']), test['variation'])
    end
  end

  # Test track
  def test_track_invalid_params
    set_up()
    assert_equal(@vwo.track(123, 456, 789), false)
  end

  def test_track_invalid_config
    set_up(0)
    assert_equal(@vwo.track(@user_id, 'somecampaign', 'somegoal'), false)
  end

  def test_track_with_no_campaign_key_found
    set_up(1)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track('NO_SUCH_CAMPAIGN_KEY', test['user'], @goal_identifier), false)
    end
  end

  def test_track_with_no_goal_identifier_found
    set_up(1)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], 'NO_SUCH_GOAL_IDENTIFIER'), false)
    end
  end

  def test_track_against_campaign_traffic_50_and_split_50_50
    set_up(1)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_r_int
    # It's goal_type is revenue, so test revenue
    set_up(2)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, 23), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_r_float
    # It's goal_type is revenue, so test revenue
    set_up(2)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, 23.3), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_r_str
    # It's goal_type is revenue, so test revenue
    set_up(2)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, '23.3'), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_no_r
    # It's goal_type is revenue, so test revenue
    set_up(2)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), false)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_50_50_kwargs
    # It's goal_type is revenue, so test revenue
    set_up(2)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier, { 'revenue_value' => 23 }), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_20_80
    set_up(3)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_20_and_split_10_90
    set_up(4)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_0_100
    set_up(5)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_track_against_campaign_traffic_100_and_split_33_x3
    set_up(6)
    USER_EXPECTATIONS[@campaign_key].each do |test|
      assert_equal(@vwo.track(@campaign_key, test['user'], @goal_identifier), !test['variation'].nil?)
    end
  end

  def test_get_settings
    set_up(6)
    assert_not_nil(@vwo.get_settings)
  end
end
